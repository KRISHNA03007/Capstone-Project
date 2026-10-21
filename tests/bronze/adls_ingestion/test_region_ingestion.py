import pytest
from pyspark.sql.types import StructType, StructField, IntegerType, StringType

def test_region_data_quality(spark):
    """Test that region data builds correctly"""
    schema = StructType([
        StructField("region_id", IntegerType(), True),
        StructField("region_name", StringType(), True),
        StructField("country", StringType(), True)
    ])
    
    test_data = [(1, "North", "USA"), (2, "South", "USA")]
    df = spark.createDataFrame(test_data, schema=schema)
    
    # Basic validation
    assert df.filter(df.region_id == 1).count() == 1
    assert "country" in df.columns
