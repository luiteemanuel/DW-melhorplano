#!/bin/bash
# Upload CSV source files and Glue script to S3
set -euo pipefail

BUCKET="${1:?Usage: upload_data.sh <bucket-name>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Uploading source data to s3://$BUCKET/source/ ..."
aws s3 cp "$ROOT_DIR/data/vendas.csv"   "s3://$BUCKET/source/vendas/vendas.csv"
aws s3 cp "$ROOT_DIR/data/clientes.csv" "s3://$BUCKET/source/clientes/clientes.csv"

echo "Uploading Glue ETL script to s3://$BUCKET/scripts/ ..."
aws s3 cp "$ROOT_DIR/glue/etl_job.py" "s3://$BUCKET/scripts/etl_job.py"

echo "Upload complete."
