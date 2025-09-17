# Peak Table Parser Service
# Parses binary peak table files from SCXRD datasets
# Based on the Python implementation in scripts/rlatt.py

class PeakTableParserService
  def initialize(binary_data)
    @binary_data = binary_data
    @data_points = []
  end

  def parse
    begin
      parse_binary_data
    rescue => e
      Rails.logger.error "PeakTableParser: Error parsing binary data: #{e.message}"
      {
        success: false,
        error: e.message,
        data_points: [],
        statistics: {}
      }
    end
  end

  private

  def parse_binary_data
    return empty_result("No binary data provided") if @binary_data.nil? || @binary_data.empty?

    io = StringIO.new(@binary_data)
    io.binmode

    # Read the number of chunks from first 8 bytes
    num_chunks_bytes = io.read(8)
    return empty_result("File too short to contain chunk count") if num_chunks_bytes.nil? || num_chunks_bytes.length < 8

    # Unpack as little-endian unsigned long long (Q<)
    num_chunks = num_chunks_bytes.unpack1("Q<")
    Rails.logger.info "PeakTableParser: Number of chunks specified in file header: #{num_chunks}"

    # Skip the remaining 304 padding bytes (312 total - 8 already read)
    io.seek(312)

    chunk_size = 168
    double_size = 8
    doubles_per_chunk = 5

    # Read exactly the number of chunks specified in the header
    (0...num_chunks).each do |i|
      chunk = io.read(chunk_size)
      if chunk.nil? || chunk.length < chunk_size
        Rails.logger.warn "PeakTableParser: Chunk #{i+1} is incomplete (#{chunk&.length || 0} bytes instead of #{chunk_size})"
        break
      end

      # Extract the 5 doubles from the beginning of the chunk
      # Format: 4 doubles (x, y, z, r) + 1 long long (i)
      doubles = chunk[0, doubles_per_chunk * double_size].unpack("ddddq")
      x, y, z, r, i = doubles

      @data_points << {
        x: x,
        y: y,
        z: z,
        r: r,
        i: i
      }
    end

    Rails.logger.info "PeakTableParser: Successfully read #{@data_points.length} data points"

    # Calculate statistics
    statistics = calculate_statistics

    {
      success: true,
      data_points: @data_points,
      statistics: statistics,
      metadata: {
        num_points: @data_points.length,
        file_size: @binary_data.length
      }
    }
  end

  def calculate_statistics
    return {} if @data_points.empty?

    # Extract coordinate arrays
    x_values = @data_points.map { |p| p[:x] }
    y_values = @data_points.map { |p| p[:y] }
    z_values = @data_points.map { |p| p[:z] }
    r_values = @data_points.map { |p| p[:r] }
    i_values = @data_points.map { |p| p[:i] }

    {
      x: calculate_array_stats(x_values),
      y: calculate_array_stats(y_values),
      z: calculate_array_stats(z_values),
      r: calculate_array_stats(r_values),
      i: calculate_array_stats(i_values)
    }
  end

  def calculate_array_stats(values)
    return {} if values.empty?

    sorted = values.sort
    mean = values.sum.to_f / values.length
    variance = values.map { |v| (v - mean) ** 2 }.sum / values.length
    std_dev = Math.sqrt(variance)

    {
      min: sorted.first,
      max: sorted.last,
      mean: mean,
      std: std_dev,
      median: sorted[sorted.length / 2],
      count: values.length
    }
  end

  def empty_result(error_message)
    {
      success: false,
      error: error_message,
      data_points: [],
      statistics: {}
    }
  end
end
