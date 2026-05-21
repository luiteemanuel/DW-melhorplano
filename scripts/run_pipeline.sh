#!/bin/bash
# Full pipeline: provision infra → upload data → run ETL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TF_DIR="$ROOT_DIR/terraform"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ── 1. Terraform ───────────────────────────────────────────────────────────────
log "Initializing Terraform..."
cd "$TF_DIR"
terraform init -input=false

log "Applying infrastructure..."
terraform apply -input=false -auto-approve

BUCKET=$(terraform output -raw s3_bucket_name)
JOB_NAME=$(terraform output -raw glue_job_name)
CRAWLER_NAME=$(terraform output -raw glue_crawler_name)

log "S3 bucket:    $BUCKET"
log "Glue job:     $JOB_NAME"
log "Crawler:      $CRAWLER_NAME"

# ── 2. Upload data + script ────────────────────────────────────────────────────
log "Uploading data and Glue script to S3..."
cd "$ROOT_DIR"
bash scripts/upload_data.sh "$BUCKET"

# ── 3. Run crawler ─────────────────────────────────────────────────────────────
log "Starting Glue crawler..."
aws glue start-crawler --name "$CRAWLER_NAME"

log "Waiting for crawler to complete..."
while true; do
    STATE=$(aws glue get-crawler --name "$CRAWLER_NAME" --query 'Crawler.State' --output text)
    log "  Crawler state: $STATE"
    [[ "$STATE" == "READY" ]] && break
    sleep 15
done

# ── 4. Run ETL job ─────────────────────────────────────────────────────────────
log "Starting Glue ETL job..."
RUN_ID=$(aws glue start-job-run --job-name "$JOB_NAME" --query 'JobRunId' --output text)
log "  Job run ID: $RUN_ID"

log "Waiting for job to complete..."
while true; do
    STATUS=$(aws glue get-job-run \
        --job-name "$JOB_NAME" \
        --run-id "$RUN_ID" \
        --query 'JobRun.JobRunState' \
        --output text)
    log "  Job status: $STATUS"
    case "$STATUS" in
        SUCCEEDED) log "ETL job completed successfully."; break ;;
        FAILED|STOPPED|TIMEOUT|ERROR)
            log "ERROR: Job ended with status $STATUS"
            aws glue get-job-run --job-name "$JOB_NAME" --run-id "$RUN_ID" \
                --query 'JobRun.ErrorMessage' --output text
            exit 1
            ;;
    esac
    sleep 20
done

log "Pipeline finished. Data loaded into Redshift."
log "Endpoint: $(cd "$TF_DIR" && terraform output -raw redshift_endpoint)"
