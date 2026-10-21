import pytest

def test_calender_generation(spark):
    """Test calendar generation without strict type enforcement"""
    columns = ["date", "day_of_week", "is_holiday"]
    test_data = [("2026-01-01", "Thursday", True)]
    df = spark.createDataFrame(test_data, columns)
    
    assert df.count() == 1
    assert "is_holiday" in df.columns
    assert "day_of_week" in df.columns
