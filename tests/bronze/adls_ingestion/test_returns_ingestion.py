import pytest

def test_returns_ingestion(spark):
    """Test returns dataframe"""
    columns = ["return_id", "transaction_id", "return_reason"]
    test_data = [(999, 50012, "Defective")]
    df = spark.createDataFrame(test_data, columns)
    
    assert df.count() == 1
    assert "return_reason" in df.columns
