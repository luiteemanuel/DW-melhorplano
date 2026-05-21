import sys
import logging
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.window import Window

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

args = getResolvedOptions(sys.argv, [
    "JOB_NAME",
    "S3_BUCKET",
    "REDSHIFT_JDBC_URL",
    "REDSHIFT_USER",
    "REDSHIFT_PASSWORD",
    "DATABASE_NAME",
    "REDSHIFT_TMP_DIR",
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

bucket = args["S3_BUCKET"]
tmp_dir = args["REDSHIFT_TMP_DIR"]

# ------- EXTRACT -------

logger.info("Lendo arquivos do S3...")

df_vendas = (
    spark.read
    .option("header", "true")
    .option("inferSchema", "true")
    .csv(f"s3://{bucket}/source/vendas/")
)

df_clientes = (
    spark.read
    .option("header", "true")
    .option("inferSchema", "true")
    .csv(f"s3://{bucket}/source/clientes/")
)

logger.info(f"vendas: {df_vendas.count()} linhas | clientes: {df_clientes.count()} linhas")

# ------- TRANSFORM -------

# dim_clientes: sem duplicatas, sem nulos no id
dim_clientes = (
    df_clientes
    .select("id_cliente", "nome", "email")
    .dropDuplicates(["id_cliente"])
    .filter(F.col("id_cliente").isNotNull())
)

# fact_vendas: join pra garantir que só entra venda com cliente existente
# gera surrogate key via row_number ordenado por data
df_joined = df_vendas.join(dim_clientes.select("id_cliente"), on="id_cliente", how="inner")

df_joined = (
    df_joined
    .select(
        F.col("data").cast("date").alias("data_venda"),
        F.col("id_cliente"),
        F.col("produto"),
        F.col("valor").cast("decimal(10,2)"),
    )
    .filter(F.col("data_venda").isNotNull() & F.col("valor").isNotNull())
)

window = Window.orderBy("data_venda", "id_cliente")
fact_vendas = df_joined.withColumn("id_venda", F.row_number().over(window))
fact_vendas = fact_vendas.select("id_venda", "data_venda", "id_cliente", "produto", "valor")

logger.info(f"dim_clientes: {dim_clientes.count()} registros")
logger.info(f"fact_vendas: {fact_vendas.count()} registros")
logger.info(f"receita total: R$ {fact_vendas.agg(F.sum('valor')).collect()[0][0]:.2f}")

# ------- LOAD -------

# nome da connection precisa bater com o que foi criado no Terraform (módulo glue)
REDSHIFT_CONN = "melhorplano-dw-redshift-conn"
redshift_db = args["REDSHIFT_JDBC_URL"].split("/")[-1]


def carregar(df, tabela):
    logger.info(f"Carregando tabela: {tabela}")
    dyn = glueContext.create_dynamic_frame.from_dataframe(df, glueContext)
    glueContext.write_dynamic_frame.from_jdbc_conf(
        frame=dyn,
        catalog_connection=REDSHIFT_CONN,
        connection_options={
            "dbtable": tabela,
            "database": redshift_db,
        },
        redshift_tmp_dir=tmp_dir,
    )


# dimensão primeiro por causa da FK
carregar(dim_clientes, "dim_clientes")
carregar(fact_vendas, "fact_vendas")

logger.info("Pipeline finalizado com sucesso.")
job.commit()
