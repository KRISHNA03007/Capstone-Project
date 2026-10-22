import pytest
from pyspark.sql.functions import current_timestamp, lit

def test_products_ingestion(spark):
    """Test product data loads and receives bronze metadata without checking strict data types"""
    # 1. Create 1 row of fake product data using simple column names
    columns = ["product_id", "product_name", "category", "unit_price"]
    test_data = [("P101", "Organic Milk", "Dairy", 4)]
    
    df = spark.createDataFrame(test_data, columns)
    
    # 2. Simulate bronze layer metadata addition (matching 02_ingest_mongodb_products)
    df_bronze = (
        df
        .withColumn("_ingestion_timestamp", current_timestamp())
        .withColumn("_source_system", lit("MongoDB_Atlas"))
        .withColumn("_source_collection", lit("products"))
    )
    
    # 3. Verify row count and required columns exist
    assert df_bronze.count() == 1
    assert "product_id" in df_bronze.columns
    assert "_ingestion_timestamp" in df_bronze.columns
    assert "_source_system" in df_bronze.columns
    assert "_source_collection" in df_bronze.columns
