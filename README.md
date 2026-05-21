# Data Warehouse — MelhorPlano

Projeto de pipeline ETL para consolidar dados de vendas e clientes num Data Warehouse na AWS, modelado em star schema.

---

## O que faz

Pega dois arquivos CSV (clientes e vendas), transforma os dados com Python/Spark e carrega num banco Redshift organizado em tabela fato + tabela dimensão. Toda a infraestrutura sobe automaticamente via Terraform.

---

## Fluxo

```
CSV local → S3 → Glue Crawler → Glue ETL (PySpark) → Redshift
```

1. Terraform cria toda a infra na AWS (S3, Glue, Redshift)
2. CSVs sobem pro S3
3. Crawler cataloga os arquivos
4. ETL transforma e carrega no Redshift

---

## Star Schema

```
dim_clientes          fact_vendas
────────────          ───────────
id_cliente PK ◀──── id_cliente FK
nome                  id_venda PK
email                 data_venda
                      produto
                      valor
```

---

## Estrutura

```
DW-melhorplano/
├── data/
│   ├── vendas.csv
│   └── clientes.csv
├── glue/
│   └── etl_job.py          # Extract → Transform → Load
├── sql/
│   └── create_schema.sql   # DDL + queries de exemplo
├── terraform/
│   ├── main.tf
│   └── modules/
│       ├── s3/
│       ├── iam/
│       ├── redshift/
│       └── glue/
└── scripts/
    ├── upload_data.sh
    └── run_pipeline.sh
```

---

## Como rodar

**Pré-requisitos:** Terraform >= 1.5, AWS CLI configurado

```bash
# 1. Configure as variáveis
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edite terraform.tfvars com sua senha do Redshift

# 2. Configure credenciais AWS
aws configure

# 3. Rode tudo
bash scripts/run_pipeline.sh
```

---

## Destruir infra

```bash
cd terraform && terraform destroy -auto-approve
```
