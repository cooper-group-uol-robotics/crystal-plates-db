require "test_helper"

class PeakTableParserServiceTest < ActiveSupport::TestCase
  def setup
    @service = PeakTableParserService.new(nil)
  end

  test "handles empty data gracefully" do
    result = @service.parse
    assert_not result[:success]
    assert_equal "No binary data provided", result[:error]
    assert_empty result[:data_points]
  end

  test "handles invalid data gracefully" do
    # Test with insufficient data
    service = PeakTableParserService.new("short")
    result = service.parse
    assert_not result[:success]
    assert_equal "File too short to contain chunk count", result[:error]
  end

  test "calculates statistics correctly" do
    # Test the private method indirectly by creating a minimal valid binary structure
    # This is a simplified test - in a real scenario you'd use actual peak table data

    # Create a minimal binary structure with 1 chunk
    num_chunks = 1
    header = [ num_chunks ].pack("Q<") # Little-endian unsigned long long
    padding = "\x00" * 304 # Remaining padding bytes

    # Create one chunk with known values
    x, y, z, r = 1.0, 2.0, 3.0, 4.0
    i = 5
    chunk_data = [ x, y, z, r, i ].pack("ddddq") # 4 doubles + 1 long long
    chunk_padding = "\x00" * (168 - 40) # Pad to 168 bytes total

    binary_data = header + padding + chunk_data + chunk_padding

    service = PeakTableParserService.new(binary_data)
    result = service.parse

    assert result[:success], "Parsing should succeed: #{result[:error]}"
    assert_equal 1, result[:data_points].length

    point = result[:data_points].first
    assert_equal 1.0, point[:x]
    assert_equal 2.0, point[:y]
    assert_equal 3.0, point[:z]
    assert_equal 4.0, point[:r]
    assert_equal 5, point[:i]

    # Check statistics
    stats = result[:statistics]
    assert_equal 1.0, stats[:x][:min]
    assert_equal 1.0, stats[:x][:max]
    assert_equal 1.0, stats[:x][:mean]
  end
end
