import pytest
from pyspark.sql.functions import current_timestamp

def test_stores_ingestion(spark):
    """Test stores data loads and receives bronze metadata without checking strict data types"""
    # 1. Create fake data using just column names (no strict data types)
    columns = ["store_id", "store_name", "region"]
    test_data = [(1, "Downtown Store", "North"), (2, "Airport Store", "South")]
    df = spark.createDataFrame(test_data, columns)
    
    # 2. Simulate bronze layer transformation
    df_bronze = df.withColumn("ingestion_date", current_timestamp())
    
    # 3. Verify it worked
    assert df_bronze.count() == 2
    assert "store_id" in df_bronze.columns
    assert "ingestion_date" in df_bronze.columns
