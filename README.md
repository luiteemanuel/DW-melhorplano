# Pipeline ETL — MelhorPlano Data Warehouse

Pipeline ETL completo para consolidação de dados de vendas e clientes em um Data Warehouse modelado em star schema, com infraestrutura provisionada via Terraform na AWS.

---

## Arquitetura

```
┌─────────────┐    ┌────────────────┐    ┌──────────────────────┐
│  Arquivos   │    │   AWS Glue     │    │   Amazon Redshift    │
│    CSV      │───▶│  ETL Job       │───▶│   Star Schema        │
│  (S3)       │    │  (PySpark)     │    │  fact + dim          │
└─────────────┘    └────────────────┘    └──────────────────────┘
       ▲                                          
       │           ┌────────────────┐             
       └───────────│  Glue Crawler  │             
                   │  (catalogação) │             
                   └────────────────┘             

Infraestrutura provisionada via Terraform
```

---

## Stack

| Componente | Tecnologia | Justificativa |
|---|---|---|
| Armazenamento fonte | Amazon S3 | Data lake nativo AWS, baixo custo, escalável |
| Catalogação | AWS Glue Crawler | Detecta schema automaticamente dos CSVs no S3 |
| ETL | AWS Glue (PySpark) | ETL serverless nativo AWS, integração direta com S3 e Redshift |
| Data Warehouse | Amazon Redshift | DW colunado MPP, otimizado para queries analíticas |
| Infraestrutura | Terraform | IaC reproducível, versionado, modular |
| Automação | Shell script | Pipeline end-to-end em um único comando |

---

## Star Schema

```
         ┌──────────────────────┐
         │    dim_clientes      │
         ├──────────────────────┤
         │ id_cliente  PK       │◀── DISTKEY
         │ nome                 │
         │ email                │
         └──────────┬───────────┘
                    │ FK
         ┌──────────▼───────────┐
         │    fact_vendas       │
         ├──────────────────────┤
         │ id_venda    PK       │
         │ data_venda           │◀── SORTKEY
         │ id_cliente  FK       │◀── DISTKEY
         │ produto              │
         │ valor   DECIMAL(10,2)│
         └──────────────────────┘
```

**Decisões de modelagem:**
- `DISTKEY (id_cliente)` em ambas as tabelas → co-location de dados, joins eficientes
- `SORTKEY (data_venda)` na fact → range scans por período otimizados
- Chave surrogate `id_venda` gerada no ETL via `row_number()` — desacoplada do sistema fonte

---

## Fontes de Dados

| Arquivo | Colunas | Descrição |
|---|---|---|
| `data/vendas.csv` | data, produto, valor, id_cliente | Transações de venda |
| `data/clientes.csv` | id_cliente, nome, email | Cadastro de clientes |

---

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) configurado (`aws configure`)
- Credenciais com permissão para: S3, Glue, Redshift, IAM

---

## Quickstart

```bash
# 1. Clone o repositório
git clone <repo-url>
cd DW-melhorplano

# 2. Configure as variáveis do Terraform
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edite terraform.tfvars com sua senha do Redshift

# 3. Execute o pipeline completo
bash scripts/run_pipeline.sh
```

O script irá:
1. Provisionar toda a infraestrutura na AWS via `terraform apply`
2. Fazer upload dos CSVs e do script Glue para o S3
3. Executar o Glue Crawler (catalogar os dados no Data Catalog)
4. Disparar o Glue ETL Job e aguardar conclusão

---

## Estrutura do Projeto

```
DW-melhorplano/
├── data/
│   ├── vendas.csv              # Fonte: transações de venda
│   └── clientes.csv            # Fonte: cadastro de clientes
├── terraform/
│   ├── main.tf                 # Root module — orquestra os módulos
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── s3/                 # Bucket S3 (dados fonte + scripts)
│       ├── iam/                # Roles: Glue + Redshift
│       ├── redshift/           # Cluster Redshift + Security Group
│       └── glue/               # Database, Crawler, Job, Connection
├── glue/
│   └── etl_job.py              # PySpark: Extract → Transform → Load
├── sql/
│   └── create_schema.sql       # DDL star schema + queries de exemplo
├── scripts/
│   ├── upload_data.sh          # Sobe CSVs e script para S3
│   └── run_pipeline.sh         # Orquestrador principal
└── .gitignore
```

---

## ETL em Detalhe

### Extract
Lê os arquivos CSV diretamente do S3 via Spark com inferência de schema:
```python
df_vendas = spark.read.option("header", "true").option("inferSchema", "true").csv(path)
```

### Transform
1. **`dim_clientes`**: deduplica por `id_cliente`, garante ausência de nulos
2. **`fact_vendas`**:
   - Valida FK: mantém apenas vendas com `id_cliente` existente em `dim_clientes`
   - Cast de `data` para `DATE`
   - Cast de `valor` para `DECIMAL(10,2)`
   - Gera `id_venda` com `row_number()` (surrogate key)

### Load
Carrega via JDBC para Redshift usando o `write_dynamic_frame.from_jdbc_conf` do GlueContext, com S3 como área de staging temporária (Redshift `COPY` internamente). Ordem de carga: `dim_clientes` → `fact_vendas` (respeita FK).

---

## Recursos Terraform Criados

| Recurso | Tipo |
|---|---|
| `aws_s3_bucket` | Bucket para fonte + scripts |
| `aws_iam_role` (glue-role) | Role do Glue com acesso a S3 e Redshift |
| `aws_iam_role` (redshift-role) | Role do Redshift para COPY do S3 |
| `aws_redshift_cluster` | Cluster `dc2.large` single-node |
| `aws_glue_catalog_database` | Database no Glue Data Catalog |
| `aws_glue_crawler` | Crawler para catalogar CSVs no S3 |
| `aws_glue_connection` | Conexão JDBC para o Redshift |
| `aws_glue_job` | Job ETL (Glue 4.0, G.1X, 2 workers) |

---

## Verificação dos Dados

Após o pipeline, conecte ao Redshift e valide:

```sql
-- Contagem de registros
SELECT COUNT(*) FROM dim_clientes;   -- 5
SELECT COUNT(*) FROM fact_vendas;    -- 20

-- Receita por cliente
SELECT
    c.nome,
    COUNT(v.id_venda)  AS total_vendas,
    SUM(v.valor)       AS receita_total,
    AVG(v.valor)       AS ticket_medio
FROM fact_vendas v
JOIN dim_clientes c USING (id_cliente)
GROUP BY c.nome
ORDER BY receita_total DESC;

-- Evolução mensal
SELECT
    DATE_TRUNC('month', data_venda) AS mes,
    SUM(valor) AS receita_mensal
FROM fact_vendas
GROUP BY 1
ORDER BY 1;
```

---

## Destruir Infraestrutura

Para evitar custos após o teste:

```bash
cd terraform
terraform destroy -auto-approve
```
