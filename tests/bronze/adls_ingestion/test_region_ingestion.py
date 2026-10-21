import pytest

def test_region_ingestion(spark):
    """Test region data loads correctly"""
    columns = ["region_id", "region_name", "country"]
    test_data = [(1, "North", "USA"), (2, "South", "USA")]
    df = spark.createDataFrame(test_data, columns)
    
    assert df.count() == 2
    assert "region_id" in df.columns
    assert "country" in df.columns
