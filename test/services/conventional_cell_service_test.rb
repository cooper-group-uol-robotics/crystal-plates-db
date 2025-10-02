require "test_helper"

class ConventionalCellServiceTest < ActiveSupport::TestCase
  def setup
    # Create test settings
    Setting.set("conventional_cell_api_enabled", "true")
    Setting.set("conventional_cell_api_endpoint", "http://localhost:8000/api/v1/lepage")
    Setting.set("conventional_cell_max_delta", "1.0")
    Setting.set("conventional_cell_api_timeout", "5")
  end

  test "enabled? always returns true" do
    assert ConventionalCellService.enabled?
  end

  test "convert_to_conventional returns nil with invalid parameters" do
    # Test with nil values
    result = ConventionalCellService.convert_to_conventional(nil, 13.87, 7.14, 90, 91.98, 90)
    assert_nil result

    # Test with zero values
    result = ConventionalCellService.convert_to_conventional(0, 13.87, 7.14, 90, 91.98, 90)
    assert_nil result

    # Test with negative values
    result = ConventionalCellService.convert_to_conventional(-10.24, 13.87, 7.14, 90, 91.98, 90)
    assert_nil result
  end

  test "valid_primitive_cell? validates parameters correctly" do
    service = ConventionalCellService

    # Valid parameters
    assert service.send(:valid_primitive_cell?, 10.24, 13.87, 7.14, 90, 91.98, 90)

    # Invalid parameters
    assert_not service.send(:valid_primitive_cell?, nil, 13.87, 7.14, 90, 91.98, 90)
    assert_not service.send(:valid_primitive_cell?, 0, 13.87, 7.14, 90, 91.98, 90)
    assert_not service.send(:valid_primitive_cell?, -1, 13.87, 7.14, 90, 91.98, 90)
  end

  test "parse_conventional_cell handles API response correctly" do
    service = ConventionalCellService

    # Valid API response
    api_response = {
      "bravais" => "mP",
      "cb_op" => "-c,-b,-a",
      "conventional_cell" => [ 7.14, 13.87, 10.24, 90, 91.98, 90 ],
      "volume" => 1013.48,
      "distance" => 0
    }

    result = service.send(:parse_conventional_cell, api_response)

    assert_equal "mP", result[:bravais]
    assert_equal "-c,-b,-a", result[:cb_op]
    assert_equal 7.14, result[:a]
    assert_equal 13.87, result[:b]
    assert_equal 10.24, result[:c]
    assert_equal 90, result[:alpha]
    assert_equal 91.98, result[:beta]
    assert_equal 90, result[:gamma]
    assert_equal 1013.48, result[:volume]
    assert_equal 0, result[:distance]

    # Invalid API response
    assert_nil service.send(:parse_conventional_cell, nil)
    assert_nil service.send(:parse_conventional_cell, {})
    assert_nil service.send(:parse_conventional_cell, { "bravais" => "mP" })
  end
end
