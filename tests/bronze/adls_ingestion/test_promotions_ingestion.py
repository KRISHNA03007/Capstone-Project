import pytest
from pyspark.sql.functions import current_timestamp

def test_promotions_ingestion(spark):
    """Test promotions ingestion logic"""
    columns = ["promo_id", "promo_name", "discount_percent"]
    test_data = [(101, "Summer Sale", 15.0)]
    df = spark.createDataFrame(test_data, columns)
    
    df_bronze = df.withColumn("ingestion_timestamp", current_timestamp())
    
    assert df_bronze.count() == 1
    assert "promo_name" in df_bronze.columns
    assert "ingestion_timestamp" in df_bronze.columns
