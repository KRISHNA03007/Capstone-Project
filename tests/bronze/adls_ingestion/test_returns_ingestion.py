import pytest
from pyspark.sql.types import StructType, StructField, IntegerType, StringType

def test_returns_schema(spark):
    """Test returns dataframe initialization"""
    schema = StructType([
        StructField("return_id", IntegerType(), True),
        StructField("transaction_id", IntegerType(), True),
        StructField("return_reason", StringType(), True)
    ])
    
    test_data = [(999, 50012, "Defective")]
    df = spark.createDataFrame(test_data, schema=schema)
    
    assert df.count() == 1
    assert df.collect()[0]["return_reason"] == "Defective"
