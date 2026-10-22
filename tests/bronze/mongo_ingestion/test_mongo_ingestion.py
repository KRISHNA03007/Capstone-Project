import pytest
from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, lit
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

# Initialize Spark session for testing
@pytest.fixture(scope="module")
def spark():
    return SparkSession.builder \
        .appName("MongoDB_Ingestion_UnitTests") \
        .getOrCreate()

# Sample mock DataFrame representing MongoDB source payload
@pytest.fixture
def sample_mongodb_data(spark):
    schema = StructType([
        StructField("customer_id", StringType(), True),
        StructField("first_name", StringType(), True),
        StructField("last_name", StringType(), True),
        StructField("email", StringType(), True)
    ])
    data = [
        ("C1001", "John", "Doe", "john.doe@example.com"),
        ("C1002", "Jane", "Smith", "jane.smith@example.com")
    ]
    return spark.createDataFrame(data, schema)


def transform_to_bronze(df, collection_name):
    """
    Transformation logic applied during MongoDB Bronze ingestion.
    """
    return (
        df
        .withColumn("_ingestion_timestamp", current_timestamp())
        .withColumn("_source_system", lit("MongoDB_Atlas"))
        .withColumn("_source_collection", lit(collection_name))
    )


# -------------------------------------------------------------------------
# Unit Tests
# -------------------------------------------------------------------------

def test_bronze_metadata_columns_added(sample_mongodb_data):
    """
    Test 1: Verify that mandatory Bronze metadata columns are added correctly.
    """
    collection = "customers"
    result_df = transform_to_bronze(sample_mongodb_data, collection)
    
    expected_columns = {"_ingestion_timestamp", "_source_system", "_source_collection"}
    actual_columns = set(result_df.columns)
    
    assert expected_columns.issubset(actual_columns), "Metadata columns are missing from Bronze DataFrame."


def test_bronze_metadata_values(sample_mongodb_data):
    """
    Test 2: Verify that _source_system and _source_collection contain expected values.
    """
    collection = "customers"
    result_df = transform_to_bronze(sample_mongodb_data, collection)
    first_row = result_df.first()
    
    assert first_row["_source_system"] == "MongoDB_Atlas", "Source system metadata value mismatch."
    assert first_row["_source_collection"] == collection, "Source collection metadata value mismatch."


def test_row_count_preservation(sample_mongodb_data):
    """
    Test 3: Verify that transformation logic does not drop or duplicate records.
    """
    collection = "customers"
    result_df = transform_to_bronze(sample_mongodb_data, collection)
    
    assert result_df.count() == sample_mongodb_data.count(), "Row count changed during Bronze transformation."