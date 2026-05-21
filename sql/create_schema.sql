-- Star Schema — MelhorPlano Data Warehouse
-- Dialect: Amazon Redshift (PostgreSQL-compatible)

CREATE TABLE IF NOT EXISTS dim_clientes (
    id_cliente INTEGER     PRIMARY KEY,
    nome       VARCHAR(200),
    email      VARCHAR(200)
)
DISTSTYLE KEY
DISTKEY (id_cliente);

CREATE TABLE IF NOT EXISTS fact_vendas (
    id_venda   INTEGER       PRIMARY KEY,
    data_venda DATE          NOT NULL,
    id_cliente INTEGER       NOT NULL REFERENCES dim_clientes(id_cliente),
    produto    VARCHAR(200),
    valor      DECIMAL(10,2)
)
DISTSTYLE KEY
DISTKEY (id_cliente)
SORTKEY (data_venda);

-- Analytical queries example
-- Total revenue per customer
SELECT
    c.nome,
    COUNT(v.id_venda)    AS total_vendas,
    SUM(v.valor)         AS receita_total,
    AVG(v.valor)         AS ticket_medio
FROM fact_vendas v
JOIN dim_clientes c USING (id_cliente)
GROUP BY c.nome
ORDER BY receita_total DESC;

-- Monthly revenue trend
SELECT
    DATE_TRUNC('month', data_venda) AS mes,
    SUM(valor)                      AS receita_mensal
FROM fact_vendas
GROUP BY 1
ORDER BY 1;
