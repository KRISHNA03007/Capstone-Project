# Capstone Project: MavenMarket Lakehouse

An end-to-end data engineering project on **Azure Databricks**. It takes retail data for a fictional grocery chain (MavenMarket) from several different sources, cleans it, and turns it into analytics-ready tables for sales, customer and returns reporting.

The project follows the **Medallion Architecture** (Bronze → Silver → Gold) on **Unity Catalog**.

---

## Architecture

```
 SOURCES                BRONZE                SILVER                  GOLD
 ───────                ──────                ──────                  ────
 ADLS Gen2 (CSV)  ──┐
 MongoDB Atlas    ──┼─►  Raw Delta tables ─►  Cleaned, typed,   ─►  Star schema +
 Kafka (streaming)──┘    + load metadata       validated tables       Materialized Views
                                               + quarantine           for dashboards
```

| Layer | What happens |
|-------|--------------|
| **Bronze** | Raw data is loaded as-is and tagged with ingestion metadata (timestamp, source system). |
| **Silver** | Data is trimmed, type-cast, de-duplicated and checked against data quality rules. Bad records go to quarantine tables. |
| **Gold** | Dimension and fact tables (star schema) plus aggregated Materialized Views for reporting. |

---

## Data Sources

| Source | Data | How it is loaded |
|--------|------|------------------|
| **ADLS Gen2** (CSV files) | Transactions, Returns, Stores, Regions, Promotions | Auto Loader (`cloudFiles`) with a rescued-data column |
| **MongoDB Atlas** | Customers, Products | Mongo Spark connector, full overwrite snapshot |
| **Kafka** | Online orders, Inventory | Structured Streaming, writes every 30 seconds |
| **Spark-generated** | Calendar (1997 to today) | Generated with `sequence()` |

Credentials (storage keys, Mongo URI, Kafka keys) are kept in an **Azure Key Vault-backed secret scope** and read with `dbutils.secrets`. Nothing sensitive is stored in the repo.

---

## Project Structure

```
├── adls_ingestion/              # Bronze: CSV files from ADLS + calendar generation
├── mongo_ingestion/             # Bronze: Customers and Products from MongoDB
├── kafka_ingestion/             # Bronze: streaming Orders and Inventory from Kafka
├── Lakeflow Declarative Pipeline/
│   ├── MavenMarket Silver Batch DLT/   # Silver: batch pipeline (use the "Updated Final" folder)
│   └── MavenMarket Silver Kafka DLT/   # Silver: streaming pipeline for Kafka data
├── GoldLayer/
│   ├── StarSchema/
│   │   ├── DimensionTables/     # dim_customer, dim_product, dim_store, dim_region, dim_promotion, dim_date
│   │   └── FactTables/          # fact_sales, fact_returns, fact_inventory
│   ├── MaterializedViews/       # Dashboard MVs (sales/profit, customer analytics, returns)
│   └── MVsDocumentation.ipynb   # Extra MV examples (e.g. revenue by region)
├── Jobs and Pipeline Configs/   # Job and pipeline definitions (batch, Kafka, Silver DLT, Gold DLT)
├── .github/workflows/deploy.yml # CI/CD pipeline
└── databricks.yml               # Databricks Asset Bundle config
```

> The Silver Batch folder also contains earlier versions of the notebooks (`transformations/`, `updated/`). The pipeline config points to **`Updated Final/`**, which is the current version.

---

## Key Features

- **Incremental loading** with Auto Loader and streaming tables
- **Batch and streaming data combined**: offline (store) and online (Kafka) transactions are unioned into one Silver transactions table
- **Data quality checks** using DLT `EXPECT` rules, with failed rows sent to `quarantine_*` tables
- **Data quality metrics table** (`dq_metrics`) showing records checked, failed and warned per table, ready for a dashboard
- **SCD Type 2** history tracking using `APPLY CHANGES`
- **Surrogate keys** on all dimensions and facts
- **Star schema** in Gold, with materialized views for monthly sales and profit, customer analytics and return rates

---

## Gold Layer Tables

**Dimensions:** `dim_customer`, `dim_product`, `dim_store`, `dim_region`, `dim_promotion`, `dim_date`

**Facts:** `fact_sales`, `fact_returns`, `fact_inventory`

**Materialized Views:**
- `gold_sales_profit_performance`: monthly sales, cost and profit by store, product and channel
- `gold_customer_analytics_performance`: customer-level spend and preferred store/region
- `gold_returns_performance`: return rates by month, store and product

---

## Tech Stack

- Azure Databricks (Delta Lake, Unity Catalog, Lakeflow Declarative Pipelines / DLT)
- PySpark and Spark SQL
- Azure Data Lake Storage Gen2 and Azure Key Vault
- MongoDB Atlas
- Apache Kafka (Confluent-style SASL_SSL connection)
- Databricks Asset Bundles
- GitHub Actions

---

## CI/CD

The workflow in `.github/workflows/deploy.yml` runs on every push and pull request to `main`:

1. **Validate bundle**: runs `databricks bundle validate`
2. **Sync to Databricks**: on push to `main`, updates the shared Databricks Git folder with the latest code

The following GitHub secrets are needed: `DATABRICKS_HOST`, `DATABRICKS_TOKEN`, `GIT_PAT`.

`databricks.yml` defines three targets, each with its own catalog:

| Target | Catalog |
|--------|---------|
| `dev` (default) | `maven_test` |
| `main` | `maven_dev` |
| `prod` | `maven_prod` |

---

## How to Run

1. **Set up Databricks**: create a workspace with Unity Catalog, and create the `bronze`, `silver` and `gold` schemas.
2. **Add secrets**: create a Key Vault-backed secret scope named `keyvaultcapstone` with the storage access key, datalake path, MongoDB URI and Kafka credentials.
3. **Install the Mongo connector** on the cluster: `org.mongodb.spark:mongo-spark-connector_2.12:10.4.0`.
4. **Run Bronze ingestion** using the batch job (daily) and the Kafka job (continuous).
5. **Run the Silver pipeline**, then the **Gold pipeline**.
6. **Query the results** from the `gold` schema or connect a BI dashboard.

To validate the bundle:

```bash
databricks bundle validate
```

---

## Author

**Krishna** · [GitHub: KRISHNA03007](https://github.com/KRISHNA03007)
