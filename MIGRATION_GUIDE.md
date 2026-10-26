# Azure Databricks Account & Workspace Migration Guide

This document lists **every configuration value, secret, credential, and path** that must be updated when migrating this project to a new Azure Databricks workspace or account.

---

## Quick Checklist Overview

| # | Component | Primary Files | What Changes |
|---|---|---|---|
| 1 | **GitHub Actions CI/CD** | Repository Secrets, `.github/workflows/deploy.yml` | Databricks Host, Token |
| 2 | **Bundle Configuration** | `databricks.yml` | SQL Warehouse ID, Catalog Name, Target Root Path |
| 3 | **Databricks Secret Scope** | Azure Key Vault / Databricks CLI | Secret Scope Name (`keyvaultcapstone`) & keys |
| 4 | **Unity Catalog** | Databricks Metastore | Catalog (`mavenmarket`) & Schemas (`bronze`, `silver`, `gold`) |
| 5 | **Storage Accounts** | Ingestion Notebooks (`adls_ingestion/*.ipynb`) | Storage account names (`capstonestaccadls`) |
| 6 | **Compute / Clusters** | `Jobs and Pipeline Configs/Job_and_pipeline_dabs/*.yml` | Node types (`Standard_D4a_v4`), Spark runtime versions |
| 7 | **Dashboards & Genie** | `dashboards/*.lvdash.json`, `src/*.json` | Embedded queries referencing catalog or persona groups |

---

## 1. GitHub Actions Secrets & CI/CD Workflow

DAB deploys all assets (notebooks, files, jobs, pipelines, dashboards, genie spaces) directly to Databricks using the Databricks CLI (`databricks bundle deploy`). A Databricks Git folder (`databricks repos`) or GitHub PAT is **no longer required**.

### GitHub Repository Secrets (Settings -> Secrets and variables -> Actions)

| Secret Name | Description | Old / Current Value | Where to Get New Value |
|---|---|---|---|
| `DATABRICKS_HOST` | Workspace URL | `https://adb-xxx.azuredatabricks.net` | New Azure Databricks workspace URL (without trailing slash) |
| `DATABRICKS_TOKEN` | Personal Access Token (PAT) or Service Principal Token | `dapi...` | User Settings -> Developer -> Access tokens -> Generate new token (or Entra ID Service Principal) |

### File: `.github/workflows/deploy.yml`
- Runs `databricks bundle validate` on pull requests and pushes.
- Runs `databricks bundle deploy -t prod` automatically on push to `main`.

---

## 2. Databricks Asset Bundle (`databricks.yml`)

### File: `databricks.yml`

```yaml
variables:
  catalog_name:
    default: mavenmarket          # <-- 1. Change if your Unity Catalog name changes
  sql_warehouse_id:
    default: "35cc87a5d9ff97c9"   # <-- 2. Change to your new SQL Warehouse ID

targets:
  prod:
    workspace:
      root_path: /Shared/.bundle/${bundle.name}/prod  # <-- 3. Verify target path
    variables:
      catalog_name: mavenmarket
      sql_warehouse_id: "35cc87a5d9ff97c9"           # <-- 4. Change here as well
```

- **Where to get New `sql_warehouse_id`**:
  1. Go to your new workspace: **SQL** -> **SQL Warehouses**.
  2. Create or select a warehouse (e.g. Serverless or Pro).
  3. Look at the URL or **Connection details** tab: copy the 16-character alphanumeric **Warehouse ID** (e.g., `a1b2c3d4e5f6g7h8`).

---

## 3. Azure Key Vault & Databricks Secret Scope

The project notebooks read credentials via `dbutils.secrets.get(scope="keyvaultcapstone", key=...)`.

### Step 1: Create the Secret Scope in New Workspace
In your new Databricks workspace, create an Azure Key Vault-backed secret scope:
```
https://<databricks-instance>#secrets/createScope
```
- **Scope Name**: `keyvaultcapstone` *(If you choose a different name, see Section 5 below)*
- **DNS Name**: Vault URI from your new Azure Key Vault (e.g., `https://<new-keyvault>.vault.azure.net/`)
- **Resource ID**: Full Resource ID of the Key Vault from the Azure Portal

### Step 2: Secret Keys Required Inside the Scope

| Secret Key Name | Used In | What to Put in It |
|---|---|---|
| `datalake-path` | `promotions_ingestion.ipynb`, `region_ingestion.ipynb`, etc. | ADLS Gen2 base path (e.g., `abfss://<container>@<storage_account>.dfs.core.windows.net/`) |
| `datalake-key` / `secret_key` | ADLS ingestion notebooks | ADLS Gen2 Storage Account Access Key |
| `mongodb-uri` | `mongo_ingestion/Customers.ipynb`, `Products.ipynb` | MongoDB Atlas connection string: `mongodb+srv://<user>:<password>@cluster.mongodb.net/` |
| `kafkabootstrapserver` | `kafka_ingestion/*.ipynb` | Kafka Bootstrap broker endpoints (e.g. Confluent Cloud / Event Hubs) |
| `kafkaapikey` | `kafka_ingestion/*.ipynb` | Kafka cluster API Key / SASL username |
| `kafkaapisecret` | `kafka_ingestion/*.ipynb` | Kafka cluster API Secret / SASL password |

---

## 4. Unity Catalog Setup

In the new workspace, ensure Unity Catalog is enabled and create the following catalog and schemas:

```sql
CREATE CATALOG IF NOT EXISTS mavenmarket;

CREATE SCHEMA IF NOT EXISTS mavenmarket.bronze;
CREATE SCHEMA IF NOT EXISTS mavenmarket.silver;
CREATE SCHEMA IF NOT EXISTS mavenmarket.gold;
```

> **Note**: If your new catalog is NOT named `mavenmarket`, update:
> 1. `catalog_name` default in `databricks.yml`.
> 2. Hardcoded schema references inside `dashboards/*.lvdash.json` (see Section 7).

---

## 5. Storage Account References inside Notebooks

Several ingestion notebooks contain a hardcoded storage account name variable:

| Notebook Path | Variable | Current Value | Action |
|---|---|---|---|
| `adls_ingestion/calender_generation.ipynb` | `storage_account_name` | `capstonestorageaccadls` | Change to your new Azure Storage Account name |
| `adls_ingestion/promotions_ingestion.ipynb` | `storage_account_name` | `capstonestaccadls` | Change to your new Azure Storage Account name |
| `adls_ingestion/region_ingestion.ipynb` | `storage_account_name` | `capstonestaccadls` | Change to your new Azure Storage Account name |
| `adls_ingestion/returns_ingestion.ipynb` | `storage_account_name` | `capstonestaccadls` | Change to your new Azure Storage Account name |
| `adls_ingestion/Stores_ingestion.ipynb` | `storage_account_name` | `capstonestaccadls` | Change to your new Azure Storage Account name |
| `adls_ingestion/transaction_ingestion.ipynb` | `storage_account_name` | `capstonestaccadls` | Change to your new Azure Storage Account name |

*(If you also change the Secret Scope name from `keyvaultcapstone`, update `secret_scope = "..."` at the top of these notebooks).*

---

## 6. Compute & Cluster Configurations

Files:
- `Jobs and Pipeline Configs/Job_and_pipeline_dabs/batch_ingestion_job.yml`
- `Jobs and Pipeline Configs/Job_and_pipeline_dabs/kafka_ingestion_job.yml`
- `Jobs and Pipeline Configs/Job_and_pipeline_dabs/silver_batch_dlt.yml`
- `Jobs and Pipeline Configs/Job_and_pipeline_dabs/gold_dlt.yml`

| Property | Current Value | When / Why to Change |
|---|---|---|
| `node_type_id` | `Standard_D4a_v4` | If your new Azure region lacks quota for `Standard_D4a_v4`, switch to another general-purpose VM like `Standard_D4s_v5` or `Standard_DS3_v2`. If migrating to AWS, use `i3.xlarge` or `m5d.large`. |
| `spark_version` | `13.3.x-scala2.12` / `14.3.x-scala2.12` | Ensure the chosen runtime LTS version is available in the new Databricks region/workspace. |
| `num_workers` | `1` (jobs), `0` (DLT single-node) | Increase worker count if processing larger batch datasets in production. |

---

## 7. Dashboards & Genie Agent

### File: `src/maven_market_executive_agent.geniespace.json`
- **Catalog references**: References tables as `mavenmarket.gold.fact_sales`, etc. If you changed the catalog name, find and replace `mavenmarket` with your new catalog name.

### Files: `dashboards/*.lvdash.json`
- **Catalog references**: Embedded SQL queries query `mavenmarket.gold...` and `mavenmarket.silver...`.
- **Persona / Entra ID Groups**: `Maven Market Secure Analytics 2.lvdash.json` uses Databricks group functions:
  ```sql
  is_member('maven_dataengineer')
  is_member('maven_executives')
  is_member('maven_analysts')
  is_member('maven_regional_managers')
  is_member('maven_central_west')
  is_member('maven_mexico_west')
  ```
  In your new workspace, create these groups under **Settings** -> **Identity and Access** -> **Groups** (or Entra ID SCIM sync) so Row-Level and Column-Level Security evaluate properly.

