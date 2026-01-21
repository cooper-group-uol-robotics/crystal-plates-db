# frozen_string_literal: true

require "test_helper"

class ScxrdDatasetSpotsTest < ActiveSupport::TestCase
  test "can set spots_found and spots_indexed" do
    dataset = scxrd_datasets(:one)
    
    dataset.spots_found = 100
    dataset.spots_indexed = 75
    
    assert dataset.valid?
    assert_equal 100, dataset.spots_found
    assert_equal 75, dataset.spots_indexed
  end

  test "validates spots_found is non-negative integer" do
    dataset = scxrd_datasets(:one)
    
    dataset.spots_found = -5
    assert_not dataset.valid?
    assert_includes dataset.errors[:spots_found], "must be greater than or equal to 0"
  end

  test "validates spots_indexed is non-negative integer" do
    dataset = scxrd_datasets(:one)
    
    dataset.spots_indexed = -10
    assert_not dataset.valid?
    assert_includes dataset.errors[:spots_indexed], "must be greater than or equal to 0"
  end

  test "allows nil values for spots" do
    dataset = scxrd_datasets(:one)
    
    dataset.spots_found = nil
    dataset.spots_indexed = nil
    
    assert dataset.valid?
  end

  test "calculate_spots_found returns nil without peak table" do
    dataset = scxrd_datasets(:one)
    
    # Ensure no peak table is attached
    dataset.peak_table.purge if dataset.peak_table.attached?
    
    result = dataset.calculate_spots_found!
    assert_nil result
  end

  test "calculate_spots_indexed returns nil without UB matrix" do
    dataset = scxrd_datasets(:one)
    
    # Clear UB matrix
    dataset.ub11 = nil
    dataset.ub22 = nil
    dataset.ub33 = nil
    
    result = dataset.calculate_spots_indexed!
    assert_nil result
  end

  test "calculate_spot_statistics returns hash with expected keys" do
    dataset = scxrd_datasets(:one)
    
    # Mock the individual calculations
    dataset.stub :calculate_spots_found!, 100 do
      dataset.stub :calculate_spots_indexed!, 75 do
        result = dataset.calculate_spot_statistics!
        
        assert_kind_of Hash, result
        assert result.key?(:spots_found)
        assert result.key?(:spots_indexed)
        assert result.key?(:indexing_rate)
        
        assert_equal 100, result[:spots_found]
        assert_equal 75, result[:spots_indexed]
        assert_in_delta 75.0, result[:indexing_rate], 0.1
      end
    end
  end

  test "indexing_rate calculation handles zero spots_found" do
    dataset = scxrd_datasets(:one)
    
    dataset.stub :calculate_spots_found!, 0 do
      dataset.stub :calculate_spots_indexed!, 0 do
        result = dataset.calculate_spot_statistics!
        
        assert_nil result[:indexing_rate]
      end
    end
  end

  test "indexing_rate calculation handles nil values" do
    dataset = scxrd_datasets(:one)
    
    dataset.stub :calculate_spots_found!, nil do
      dataset.stub :calculate_spots_indexed!, nil do
        result = dataset.calculate_spot_statistics!
        
        assert_nil result[:indexing_rate]
      end
    end
  end
end
