import pytest
from pyspark.sql import SparkSession

@pytest.fixture(scope="session")
def spark():
    """Creates a local Spark session for testing"""
    return SparkSession.builder \
        .master("local[1]") \
        .appName("pytest-pyspark-local") \
        .getOrCreate()
