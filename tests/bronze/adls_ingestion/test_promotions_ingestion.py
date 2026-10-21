import pytest
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DoubleType
from pyspark.sql.functions import current_timestamp

def test_promotions_schema_and_metadata(spark):
    """Test promotions schema and bronze metadata injection"""
    schema = StructType([
        StructField("promo_id", IntegerType(), True),
        StructField("promo_name", StringType(), True),
        StructField("discount_percent", DoubleType(), True)
    ])
    
    test_data = [(101, "Summer Sale", 15.0)]
    df = spark.createDataFrame(test_data, schema=schema)
    
    # Test adding bronze layer metadata
    df_bronze = df.withColumn("ingestion_timestamp", current_timestamp())
    
    assert df_bronze.count() == 1
    assert "ingestion_timestamp" in df_bronze.columns
