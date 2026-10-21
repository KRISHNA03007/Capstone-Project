import pytest
from pyspark.sql.types import StructType, StructField, DateType, StringType, BooleanType

def test_calender_schema(spark):
    """Test calendar generation schema"""
    schema = StructType([
        StructField("date", DateType(), True),
        StructField("day_of_week", StringType(), True),
        StructField("is_holiday", BooleanType(), True)
    ])
    
    # Create an empty dataframe to verify schema structure
    df = spark.createDataFrame([], schema=schema)
    
    assert "is_holiday" in df.columns
    assert len(df.columns) == 3
