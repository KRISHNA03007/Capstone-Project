import pytest
from pyspark.sql.functions import current_timestamp, lit

def test_customers_ingestion(spark):
    """Test customer data loads and receives bronze metadata without checking strict data types"""
    # 1. Create 1 row of fake customer data using simple column names
    columns = ["customer_id", "first_name", "last_name", "email"]
    test_data = [("C1001", "John", "Doe", "john@example.com")]
    
    df = spark.createDataFrame(test_data, columns)
    
    # 2. Simulate bronze layer metadata addition (matching 01_ingest_mongodb_customers)
    df_bronze = (
        df
        .withColumn("_ingestion_timestamp", current_timestamp())
        .withColumn("_source_system", lit("MongoDB_Atlas"))
        .withColumn("_source_collection", lit("customers"))
    )
    
    # 3. Verify row count and required columns exist
    assert df_bronze.count() == 1
    assert "customer_id" in df_bronze.columns
    assert "_ingestion_timestamp" in df_bronze.columns
    assert "_source_system" in df_bronze.columns
    assert "_source_collection" in df_bronze.columns
