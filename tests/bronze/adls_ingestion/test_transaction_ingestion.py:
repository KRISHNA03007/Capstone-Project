import pytest
from pyspark.sql.functions import current_timestamp

def test_transaction_ingestion(spark):
    """Test main sales transactions"""
    columns = ["transaction_id", "store_id", "total_amount"]
    test_data = [(50012, 1, 120.50), (50013, 2, 45.00)]
    df = spark.createDataFrame(test_data, columns)
    
    df_bronze = df.withColumn("ingestion_timestamp", current_timestamp())
    
    assert df_bronze.count() == 2
    assert "transaction_id" in df_bronze.columns
    assert "ingestion_timestamp" in df_bronze.columns
