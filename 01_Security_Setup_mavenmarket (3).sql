-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 01_Security_Setup– personas, grants, row-level security, masking
-- MAGIC
-- MAGIC | Persona (account group) | Rows | PII (name, address, DOB...) | Cost / profit |
-- MAGIC |---|---|---|---|
-- MAGIC | `maven_dataengineer` | all regions | clear text | visible |
-- MAGIC | `maven_executives` | all regions | masked | visible |
-- MAGIC | `maven_analysts` | all regions | masked | hidden (NULL) |
-- MAGIC | `maven_regional_managers`  | only that region | masked | hidden (NULL) |
-- MAGIC | `maven_central_west` / `maven_mexico_west` | region groups (see `region_group_map`) | | |
-- MAGIC
-- MAGIC

-- COMMAND ----------

-- MAGIC %md ## 1. Security schema + region -> group mapping
-- MAGIC

-- COMMAND ----------

CREATE SCHEMA IF NOT EXISTS mavenmarket.security
COMMENT 'Region-to-group mapping used by the secure views';

-- COMMAND ----------

CREATE TABLE IF NOT EXISTS mavenmarket.security.region_group_map (
  group_name   STRING COMMENT 'Databricks account group',
  sales_region STRING COMMENT 'Exact value of gold.dim_region.sales_region_name that the group may see'
);

-- COMMAND ----------

DELETE FROM mavenmarket.security.region_group_map;

INSERT INTO mavenmarket.security.region_group_map VALUES
  ('maven_central_west', 'Central West'),
  ('maven_mexico_west',  'Mexico West');

SELECT * FROM mavenmarket.security.region_group_map;

-- COMMAND ----------

-- MAGIC %md ## 2. Secure dynamic views (the ONLY objects consumers and dashboards query)
-- MAGIC Each view starts with a one-row CTE `me` that evaluates the caller's persona once.
-- MAGIC * Row filter  -> `WHERE me.sees_all_regions OR r.sales_region_name IN (<regions of my region groups>)`
-- MAGIC * PII mask    -> `CASE WHEN me.is_engineer THEN col ELSE '*** MASKED ***' END`
-- MAGIC * Financial   -> `CASE WHEN me.can_see_financials THEN col ELSE NULL END`

-- COMMAND ----------

CREATE OR REPLACE VIEW mavenmarket.gold.v_sales_secure
COMMENT 'Sales for dashboards. Row-level security by region; cost/profit visible only to data engineers and executives.'
AS
WITH me AS (
  SELECT
    (is_account_group_member('maven_dataengineer') OR current_user() = 'maven_dataengineer')                                   AS is_engineer,
    ( (is_account_group_member('maven_dataengineer') OR current_user() = 'maven_dataengineer')
      OR (is_account_group_member('maven_executives') OR current_user() = 'maven_executives')
      OR (is_account_group_member('maven_analysts') OR current_user() = 'maven_analysts') )                                 AS sees_all_regions,
    ( (is_account_group_member('maven_dataengineer') OR current_user() = 'maven_dataengineer')
      OR (is_account_group_member('maven_executives') OR current_user() = 'maven_executives') )                              AS can_see_financials
)
SELECT f.sales_fact_sk,
       f.transaction_date_sk,
       d.calendar_date, d.year_number, d.month_number, d.month_name, d.year_month_code,
       r.sales_region_name   AS sales_region,
       r.sales_district_name AS sales_district,
       s.store_id, s.store_name, s.city_name AS store_city, s.country_name AS store_country,
       f.product_sk, p.product_name, p.brand_name, p.category_name,
       f.customer_sk, f.promotion_sk, f.transaction_mode,
       f.sales_quantity,
       f.gross_revenue_amount,
       CASE WHEN me.can_see_financials THEN f.total_cost_amount   ELSE NULL END AS total_cost_amount,
       CASE WHEN me.can_see_financials THEN f.gross_profit_amount ELSE NULL END AS gross_profit_amount
FROM mavenmarket.gold.fact_sales f
CROSS JOIN me
LEFT JOIN mavenmarket.gold.dim_store   s ON f.store_sk            = s.store_sk
LEFT JOIN mavenmarket.gold.dim_region  r ON s.region_sk           = r.region_sk
LEFT JOIN mavenmarket.gold.dim_product p ON f.product_sk          = p.product_sk
LEFT JOIN mavenmarket.gold.dim_date    d ON f.transaction_date_sk = d.date_sk
WHERE me.sees_all_regions
   OR r.sales_region_name IN (SELECT m.sales_region
                              FROM mavenmarket.security.region_group_map m
                              WHERE is_account_group_member(m.group_name) OR current_user() = m.group_name);

-- COMMAND ----------

CREATE OR REPLACE VIEW mavenmarket.gold.v_returns_secure
COMMENT 'Returns for dashboards. Row-level security by region.'
AS
WITH me AS (
  SELECT
    ( (is_account_group_member('maven_dataengineer') OR current_user() = 'maven_dataengineer')
      OR (is_account_group_member('maven_executives') OR current_user() = 'maven_executives')
      OR (is_account_group_member('maven_analysts') OR current_user() = 'maven_analysts') ) AS sees_all_regions
)
SELECT f.returns_fact_sk,
       d.calendar_date, d.year_number, d.month_number, d.month_name, d.year_month_code,
       r.sales_region_name   AS sales_region,
       r.sales_district_name AS sales_district,
       s.store_id, s.store_name,
       f.product_sk, p.product_name, p.brand_name, p.category_name,
       f.return_quantity
FROM mavenmarket.gold.fact_returns f
CROSS JOIN me
LEFT JOIN mavenmarket.gold.dim_store   s ON f.store_sk        = s.store_sk
LEFT JOIN mavenmarket.gold.dim_region  r ON s.region_sk       = r.region_sk
LEFT JOIN mavenmarket.gold.dim_product p ON f.product_sk      = p.product_sk
LEFT JOIN mavenmarket.gold.dim_date    d ON f.return_date_key = d.date_sk
WHERE me.sees_all_regions
   OR r.sales_region_name IN (SELECT m.sales_region
                              FROM mavenmarket.security.region_group_map m
                              WHERE is_account_group_member(m.group_name) OR current_user() = m.group_name);

-- COMMAND ----------

CREATE OR REPLACE VIEW mavenmarket.gold.v_customer_secure
COMMENT 'Customer attributes; PII masked for everyone except data engineers. Account number and exact income are not exposed.'
AS
WITH me AS (
  SELECT (is_account_group_member('maven_dataengineer') OR current_user() = 'maven_dataengineer') AS is_engineer
)
SELECT c.customer_sk, c.customer_id,
       CASE WHEN me.is_engineer THEN c.first_name     ELSE '*** MASKED ***' END AS first_name,
       CASE WHEN me.is_engineer THEN c.last_name      ELSE '*** MASKED ***' END AS last_name,
       CASE WHEN me.is_engineer THEN c.full_name      ELSE '*** MASKED ***' END AS full_name,
       CASE WHEN me.is_engineer THEN c.birth_date     ELSE make_date(year(c.birth_date), 1, 1) END AS birth_date,
       c.age_years,
       CASE WHEN me.is_engineer THEN c.street_address ELSE '*** MASKED ***' END AS street_address,
       CASE WHEN me.is_engineer THEN c.postal_code    ELSE '*** MASKED ***' END AS postal_code,
       c.city_name, c.state_province_code, c.country_name,
       c.gender_code, c.marital_status_code, c.education_level, c.occupation_name, c.homeowner_flag,
       c.yearly_income_range, c.account_open_date,
       c.start_at_timestamp, c.end_at_timestamp, c.is_current_flag
FROM mavenmarket.gold.dim_customer c
CROSS JOIN me;

-- COMMAND ----------

-- MAGIC %md ## 3. Grants per persona (least privilege: views only, never base tables)

-- COMMAND ----------

-- Everyone who consumes data: browse catalog + gold schema (no function/security-schema grants needed any more)
GRANT USE CATALOG ON CATALOG mavenmarket TO `maven_analysts`;
GRANT USE CATALOG ON CATALOG mavenmarket TO `maven_executives`;
GRANT USE CATALOG ON CATALOG mavenmarket TO `maven_regional_managers`;
GRANT USE SCHEMA  ON SCHEMA  mavenmarket.gold TO `maven_analysts`;
GRANT USE SCHEMA  ON SCHEMA  mavenmarket.gold TO `maven_executives`;
GRANT USE SCHEMA  ON SCHEMA  mavenmarket.gold TO `maven_regional_managers`;

-- Secure views only
GRANT SELECT ON TABLE mavenmarket.gold.v_sales_secure    TO `maven_analysts`;
GRANT SELECT ON TABLE mavenmarket.gold.v_returns_secure  TO `maven_analysts`;
GRANT SELECT ON TABLE mavenmarket.gold.v_customer_secure TO `maven_analysts`;

GRANT SELECT ON TABLE mavenmarket.gold.v_sales_secure    TO `maven_executives`;
GRANT SELECT ON TABLE mavenmarket.gold.v_returns_secure  TO `maven_executives`;
GRANT SELECT ON TABLE mavenmarket.gold.v_customer_secure TO `maven_executives`;

GRANT SELECT ON TABLE mavenmarket.gold.v_sales_secure    TO `maven_regional_managers`;
GRANT SELECT ON TABLE mavenmarket.gold.v_returns_secure  TO `maven_regional_managers`;
-- (regional managers deliberately get NO customer view)

-- Region groups also get the same grants directly, so the workspace role switcher works when you pick a region group
-- (a group is NOT automatically a member of maven_regional_managers).
GRANT USE CATALOG ON CATALOG mavenmarket TO `maven_central_west`;
GRANT USE CATALOG ON CATALOG mavenmarket TO `maven_mexico_west`;
GRANT USE SCHEMA  ON SCHEMA  mavenmarket.gold TO `maven_central_west`;
GRANT USE SCHEMA  ON SCHEMA  mavenmarket.gold TO `maven_mexico_west`;
GRANT SELECT ON TABLE mavenmarket.gold.v_sales_secure   TO `maven_central_west`;
GRANT SELECT ON TABLE mavenmarket.gold.v_customer_secure   TO `maven_central_west`;
GRANT SELECT ON TABLE mavenmarket.gold.v_returns_secure TO `maven_central_west`;
GRANT SELECT ON TABLE mavenmarket.gold.v_sales_secure   TO `maven_mexico_west`;
GRANT SELECT ON TABLE mavenmarket.gold.v_returns_secure TO `maven_mexico_west`;
GRANT SELECT ON TABLE mavenmarket.gold.v_customer_secure TO `maven_mexico_west`;


-- Region group members do NOT need their own grants: they are also members of maven_regional_managers.
-- region_group_map needs no consumer grant: the view reads it with the view OWNER's rights.

-- COMMAND ----------

-- Data engineers: full build rights on the whole catalog (bronze/silver/gold/security + volumes for checkpoints)
GRANT USE CATALOG, USE SCHEMA, SELECT, MODIFY, EXECUTE,
      CREATE SCHEMA, CREATE TABLE, CREATE VOLUME, READ VOLUME, WRITE VOLUME
  ON CATALOG mavenmarket TO `maven_dataengineer`;

-- COMMAND ----------

-- MAGIC %md ## 4. Close the back door (IMPORTANT)
-- MAGIC Your `SHOW GRANTS` output showed **`account users` holds ALL PRIVILEGES on catalog `mavenmarket`**.
-- MAGIC While that exists, *every* user in the account can read the raw gold tables and all RBAC is bypassed.
-- MAGIC
-- MAGIC Run the next cell **only after** (a) all teammates are in `maven_dataengineer` and (b) Step 3 has been executed.
-- MAGIC It is commented out on purpose so "Run all" cannot lock your teammates out by accident.

-- COMMAND ----------

-- >>> UNCOMMENT AND RUN ONCE, AFTER CHECKING TEAMMATES ARE IN maven_dataengineer <<<
-- REVOKE ALL PRIVILEGES      ON CATALOG mavenmarket FROM `account users`;
-- REVOKE MANAGE              ON CATALOG mavenmarket FROM `account users`;
-- REVOKE EXTERNAL USE SCHEMA ON CATALOG mavenmarket FROM `account users`;
-- REVOKE READ METADATA       ON CATALOG mavenmarket FROM `account users`;

-- COMMAND ----------

-- MAGIC %md ## 5. Ownership (so views keep working if a person leaves)
-- MAGIC The views read base tables with the **owner's** rights. Make a group the owner (group must have SELECT on gold + security: given in Step 3).

-- COMMAND ----------

ALTER SCHEMA mavenmarket.security                OWNER TO `maven_dataengineer`;
ALTER TABLE  mavenmarket.security.region_group_map OWNER TO `maven_dataengineer`;
ALTER VIEW   mavenmarket.gold.v_sales_secure     OWNER TO `maven_dataengineer`;
ALTER VIEW   mavenmarket.gold.v_returns_secure   OWNER TO `maven_dataengineer`;
ALTER VIEW   mavenmarket.gold.v_customer_secure  OWNER TO `maven_dataengineer`;

-- COMMAND ----------

-- MAGIC %md ## 6. Evidence / verification

-- COMMAND ----------

SHOW GRANTS ON SCHEMA mavenmarket.gold;

-- COMMAND ----------

SHOW GRANTS ON TABLE mavenmarket.gold.v_sales_secure;

-- COMMAND ----------

-- Who am I and which personas apply to me?
SELECT current_user() AS me,
       (is_account_group_member('maven_dataengineer') OR current_user() = 'maven_dataengineer')      AS is_engineer,
       (is_account_group_member('maven_executives') OR current_user() = 'maven_executives')        AS is_executive,
       (is_account_group_member('maven_analysts') OR current_user() = 'maven_analysts')          AS is_analyst,
       (is_account_group_member('maven_regional_managers') OR current_user() = 'maven_regional_managers') AS is_regional_manager,
       (is_account_group_member('maven_central_west') OR current_user() = 'maven_central_west')      AS in_central_west,
       (is_account_group_member('maven_mexico_west') OR current_user() = 'maven_mexico_west')       AS in_mexico_west;

-- COMMAND ----------

-- Run this SAME query as each persona. Expected:
--   engineer / executive : 7 regions, profit filled
--   analyst              : 7 regions, profit NULL
--   regional mgr         : only own region, profit NULL
SELECT sales_region, COUNT(*) AS row_count,
       SUM(gross_revenue_amount) AS revenue,
       SUM(gross_profit_amount)  AS profit
FROM mavenmarket.gold.v_sales_secure
GROUP BY 1 ORDER BY 1;

-- COMMAND ----------

-- Expected: engineer = real names; everybody else = *** MASKED ***, birth_date = 1 Jan of the year
SELECT customer_id, full_name, birth_date, street_address, postal_code
FROM mavenmarket.gold.v_customer_secure
LIMIT 5;

-- COMMAND ----------

-- Negative test (run as analyst / manager): must FAIL with a permission error
SELECT * FROM mavenmarket.gold.fact_sales LIMIT 1;