import pytest
from pyspark.sql.types import StructType, StructField, StringType, IntegerType
from pyspark.sql.functions import current_timestamp

def test_stores_schema_definition(spark):
    """Test that the Stores schema matches ADLS expectations"""
    # 1. Define the schema you expect your Stores data to have
    schema = StructType([
        StructField("store_id", IntegerType(), True),
        StructField("store_name", StringType(), True),
        StructField("region", StringType(), True)
    ])
    
    # 2. Create fake test data
    test_data = [(1, "Downtown Store", "North"), (2, "Airport Store", "South")]
    df = spark.createDataFrame(test_data, schema=schema)
    
    # 3. Assert the dataframe built correctly
    assert df.count() == 2
    assert "store_id" in df.columns

def test_ingestion_metadata(spark):
    """Test adding a bronze ingestion timestamp"""
    schema = StructType([StructField("store_id", IntegerType(), True)])
    df = spark.createDataFrame([(1,)], schema=schema)
    
    # Simulate adding an ingestion date column (common in Bronze layer)
    df_with_meta = df.withColumn("ingestion_date", current_timestamp())
    
    assert "ingestion_date" in df_with_meta.columns
