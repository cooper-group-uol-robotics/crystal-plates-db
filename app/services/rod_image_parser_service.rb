class RodImageParserService
  # Based on FormatROD.py from dxtbx
  # https://github.com/cctbx/dxtbx/blob/main/src/dxtbx/format/FormatROD.py

  # TY6 compression constants
  BLOCKSIZE = 8
  SHORT_OVERFLOW = 254
  LONG_OVERFLOW = 255
  SHORT_OVERFLOW_SIGNED = SHORT_OVERFLOW - 127
  LONG_OVERFLOW_SIGNED = LONG_OVERFLOW - 127

  def initialize(image_data)
    @image_data = image_data.respond_to?(:read) ? image_data.read : image_data
    @header = {}
    @image_array = nil
  end

  def parse
    return @result if @result

    Rails.logger.info "ROD Parser: Starting rodhypix file parsing"

    begin
      parse_header
      parse_image_data

      @result = {
        success: true,
        dimensions: [ @header[:im_npx_x], @header[:im_npx_y] ],
        pixel_size: [ @header[:real_px_size_x], @header[:real_px_size_y] ],
        image_data: @image_array,
        metadata: extract_metadata
      }

      Rails.logger.info "ROD Parser: Successfully parsed #{@header[:im_npx_x]}x#{@header[:im_npx_y]} image"
      @result
    rescue => e
      Rails.logger.error "ROD Parser: Error parsing rodhypix file: #{e.message}"
      Rails.logger.error "ROD Parser: Backtrace: #{e.backtrace.first(5).join("\n")}"

      {
        success: false,
        error: e.message,
        dimensions: [ 0, 0 ],
        pixel_size: [ 0.0, 0.0 ],
        image_data: [],
        metadata: {}
      }
    end
  end

  private

  def parse_header
    Rails.logger.info "ROD Parser: Parsing headers"

    # First, let's try to parse the text header to get basic info
    parse_text_header

    # Then parse the binary header
    parse_binary_header

    Rails.logger.info "ROD Parser: Header parsed successfully - #{@header[:im_npx_x]}x#{@header[:im_npx_y]} pixels, compression: #{@header[:compression_type]}"
  end

  def parse_text_header
    # The file starts with a text header, parse it exactly like Python implementation
    text_section = @image_data[0, 256].force_encoding("ASCII-8BIT")
    lines = text_section.split("\n")

    @text_header = {}

    # Parse version line
    if lines.length >= 1
      vers = lines[0].split
      if vers.length >= 2 && vers[0] == "OD" && vers[1] == "SAPPHIRE"
        @text_header["version"] = vers[-1].to_f if vers.length > 2
      end
    end

    # Parse compression line
    if lines.length >= 2
      compression = lines[1].split("=")
      if compression[0] == "COMPRESSION"
        @text_header["compression"] = compression[1]
        Rails.logger.info "ROD Parser: Found COMPRESSION=#{@text_header["compression"]} in text header"
      end
    end

    # Extract definitions from lines 3-5 using regex like Python
    defn_regex = /([A-Z]+=[ 0-9]+)/
    (2...5).each do |line_idx|
      next if line_idx >= lines.length
      line = lines[line_idx]
      matches = line.scan(defn_regex)
      matches.each do |match|
        n, v = match[0].split("=")
        @text_header[n] = v.to_i
        Rails.logger.info "ROD Parser: Found #{n}=#{v} in text header"
      end
    end

    # Parse time line
    if lines.length >= 6
      time_line = lines[5]
      if time_line.include?("TIME=")
        @text_header["time"] = time_line.split("TIME=")[-1].strip.gsub("\x1a", "").rstrip
      end
    end

    Rails.logger.info "ROD Parser: Text header parsed: #{@text_header}"
  end

  def parse_binary_header
    Rails.logger.info "ROD Parser: Parsing binary header for FormatRODArc"

    # Header structure constants from FormatRODArc.py
    offset = 256
    general_nbytes = 512
    special_nbytes = 768
    km4gonio_nbytes = 1024
    statistics_nbytes = 512
    history_nbytes = 2048
    nbytes = 5120

    Rails.logger.info "ROD Parser: Reading binary header sections from offset #{offset}"

    # Read binning info (offset + 24, 8 bytes)
    bin_data = read_bytes(offset + 24, 8)
    @header[:bin_x], @header[:bin_y] = bin_data.unpack("L<L<")
    Rails.logger.info "ROD Parser: Binning: #{@header[:bin_x]}x#{@header[:bin_y]}"

    # Read image dimensions (offset + 32, 16 bytes)
    dim_data = read_bytes(offset + 32, 16)
    @header[:chip_npx_x], @header[:chip_npx_y], @header[:im_npx_x], @header[:im_npx_y] = dim_data.unpack("L<L<L<L<")
    Rails.logger.info "ROD Parser: Binary header dimensions: chip=#{@header[:chip_npx_x]}x#{@header[:chip_npx_y]}, image=#{@header[:im_npx_x]}x#{@header[:im_npx_y]}"

    # If binary header dimensions look wrong, use text header values
    if @header[:im_npx_x] == 0 || @header[:im_npx_y] == 0 || @header[:im_npx_x] > 10000 || @header[:im_npx_y] > 10000
      Rails.logger.warn "ROD Parser: Binary header dimensions look incorrect, using text header values"
      @header[:im_npx_x] = @header[:text_nx] if @header[:text_nx]
      @header[:im_npx_y] = @header[:text_ny] if @header[:text_ny]
      Rails.logger.info "ROD Parser: Using corrected dimensions: #{@header[:im_npx_x]}x#{@header[:im_npx_y]}"
    end

    # Read gain and overflow settings (offset + 48, 16 bytes)
    gain_data = read_bytes(offset + 48, 16)
    @header[:gain], @header[:overflow_flag], @header[:overflow_after_remeasure_flag], @header[:overflow_threshold] = gain_data.unpack("L<L<L<L<")
    Rails.logger.info "ROD Parser: Gain: #{@header[:gain]}, Overflow threshold: #{@header[:overflow_threshold]}"

    # Read compression type (offset + 88, 4 bytes)
    compression_data = read_bytes(offset + 88, 4)
    @header[:compression_type] = compression_data.unpack("L<")[0]
    Rails.logger.info "ROD Parser: Binary compression type: #{@header[:compression_type]}"

    # If compression type from text header suggests TY6, set it to 6
    if @header[:text_compression] == "TY6" && (@header[:compression_type] == 0 || @header[:compression_type] > 10)
      Rails.logger.info "ROD Parser: Setting compression type to 6 based on text header TY6"
      @header[:compression_type] = 6
    end

    # Read pixel sizes from special section (offset + general_nbytes + 568, 16 bytes)
    begin
      pixel_size_offset = offset + general_nbytes + 568
      pixel_size_data = read_bytes(pixel_size_offset, 16)
      @header[:real_px_size_x], @header[:real_px_size_y] = pixel_size_data.unpack("e*") # Use platform native double
      Rails.logger.info "ROD Parser: Pixel sizes: #{@header[:real_px_size_x]}, #{@header[:real_px_size_y]}"
    rescue => e
      Rails.logger.warn "ROD Parser: Could not read pixel sizes: #{e.message}"
      @header[:real_px_size_x], @header[:real_px_size_y] = [ 0.1, 0.1 ] # Default values
    end

    # Read detector distance (offset + general_nbytes + special_nbytes + 712, 8 bytes)
    begin
      distance_offset = offset + general_nbytes + special_nbytes + 712
      distance_data = read_bytes(distance_offset, 8)
      @header[:distance_mm] = distance_data.unpack("e")[0] # Use platform native double
      Rails.logger.info "ROD Parser: Detector distance: #{@header[:distance_mm]} mm"
    rescue => e
      Rails.logger.warn "ROD Parser: Could not read detector distance: #{e.message}"
      @header[:distance_mm] = 100.0 # Default value
    end

    # Read direct beam position (offset + general_nbytes + special_nbytes + 664, 16 bytes)
    begin
      origin_offset = offset + general_nbytes + special_nbytes + 664
      origin_data = read_bytes(origin_offset, 16)
      @header[:origin_px_x], @header[:origin_px_y] = origin_data.unpack("e*")
      Rails.logger.info "ROD Parser: Beam center: #{@header[:origin_px_x]}, #{@header[:origin_px_y]}"
    rescue => e
      Rails.logger.warn "ROD Parser: Could not read beam center: #{e.message}"
      @header[:origin_px_x], @header[:origin_px_y] = [ 400.0, 387.5 ] # Default center for 800x775
    end

    # Check if this is a FormatRODArc file (detector type 12 or 14)
    begin
      detector_type_offset = offset + general_nbytes + 548
      detector_type_data = read_bytes(detector_type_offset, 4)
      detector_type = detector_type_data.unpack("l<")[0]
      Rails.logger.info "ROD Parser: Detector type: #{detector_type}"

      if [ 12, 14 ].include?(detector_type)
        Rails.logger.info "ROD Parser: This is a FormatRODArc file (multi-panel detector)"
        parse_arc_specific_header(nbytes)
      else
        Rails.logger.info "ROD Parser: This is a standard FormatROD file"
      end
    rescue => e
      Rails.logger.warn "ROD Parser: Could not read detector type: #{e.message}"
    end
  end

  def parse_arc_specific_header(nbytes)
    Rails.logger.info "ROD Parser: Parsing FormatRODArc specific header"

    # Seek to the end of the standard version 3 header and into the
    # extra camera parameters section
    begin
      arc_offset = nbytes + 268
      arc_data = read_bytes(arc_offset, 12)
      ix, iy, nx, ny, gapx, gapy = arc_data.unpack("s<s<s<s<s<s<")

      Rails.logger.info "ROD Parser: Arc parameters - ix: #{ix}, iy: #{iy}, nx: #{nx}, ny: #{ny}, gapx: #{gapx}, gapy: #{gapy}"

      # Validate Arc parameters
      if ix == 2 || ix == 3 # 2 or 3 panels
        if ny == 775 && nx == 385 && gapx == 30 && gapy == 0
          Rails.logger.info "ROD Parser: Valid FormatRODArc parameters detected"
          @header[:arc_nx] = nx
          @header[:arc_ny] = ny
          @header[:arc_gap_px] = gapx
          @header[:arc_panels] = ix

          # Override the image dimensions for Arc format
          @header[:im_npx_x] = ix * nx + (ix - 1) * gapx  # Total width including gaps
          @header[:im_npx_y] = ny

          Rails.logger.info "ROD Parser: Arc image dimensions corrected to #{@header[:im_npx_x]}x#{@header[:im_npx_y]}"
        else
          Rails.logger.warn "ROD Parser: Unexpected Arc parameters - nx: #{nx}, ny: #{ny}, gapx: #{gapx}, gapy: #{gapy}"
        end
      else
        Rails.logger.warn "ROD Parser: Unexpected Arc panel count: #{ix}"
      end
    rescue => e
      Rails.logger.error "ROD Parser: Could not parse Arc-specific header: #{e.message}"
    end
  end

  def parse_image_data
    Rails.logger.info "ROD Parser: Starting image data parsing"

    # Get image dimensions from text header
    nx = @header[:im_npx_x] || @text_header["NX"]
    ny = @header[:im_npx_y] || @text_header["NY"]

    if nx.nil? || ny.nil?
      Rails.logger.error "ROD Parser: Missing image dimensions"
      @image_array = Array.new(1, 0)
      return
    end

    Rails.logger.info "ROD Parser: Image dimensions: #{nx}x#{ny}"

    # Debug text header
    Rails.logger.info "ROD Parser: @text_header is: #{@text_header.inspect}"

    compression_type = (@text_header && @text_header["compression"]) || "TY6"
    Rails.logger.info "ROD Parser: Using compression type: #{compression_type}"

    if compression_type.start_with?("TY6")
      Rails.logger.info "ROD Parser: Using TY6 decompression"
      @image_array = decode_ty6_compressed_image(nx, ny)
    else
      Rails.logger.error "ROD Parser: Unsupported compression: #{compression_type}"
      @image_array = Array.new(nx * ny, 0)
    end

    Rails.logger.info "ROD Parser: Image data parsed successfully"
  end

  def decode_ty6_compressed_image(nx, ny)
    Rails.logger.info "ROD Parser: Decoding TY6 compressed image (#{nx}x#{ny}) - exact Python implementation"

    # Use the exact same offset calculation as Python implementation
    # NHEADER should be in the text header, but fallback to calculated offset if not available
    offset = (@text_header && @text_header["NHEADER"]) || 5120
    Rails.logger.info "ROD Parser: Image data starts at offset #{offset}"

    # Read the compressed field size (4 bytes, little-endian signed)
    lbytesincompressedfield_bytes = read_bytes(offset, 4)
    lbytesincompressedfield = lbytesincompressedfield_bytes.unpack("l<")[0]
    Rails.logger.info "ROD Parser: Compressed field size: #{lbytesincompressedfield} bytes"

    # Read the compressed line data
    linedata = read_bytes(offset + 4, lbytesincompressedfield)
    Rails.logger.info "ROD Parser: Read #{linedata.bytesize} bytes of compressed line data"

    # Read the line offsets (ny * 4 bytes, little-endian unsigned)
    offsets_bytes = read_bytes(offset + 4 + lbytesincompressedfield, ny * 4)
    offsets = offsets_bytes.unpack("V*")  # Little-endian 32-bit unsigned
    Rails.logger.info "ROD Parser: Line offsets: #{offsets.first(5)}... (showing first 5)"

    # Decode each line using the exact Python algorithm
    image = Array.new(ny) { Array.new(nx, 0) }

    (0...ny).each do |iy|
      line_offset = offsets[iy]
      next if line_offset >= linedata.bytesize

      line_data = linedata[line_offset..-1]
      image[iy] = decode_ty6_line_python(line_data, nx)

      if iy < 3 || iy % (ny / 10) == 0  # Log progress
        Rails.logger.debug "ROD Parser: Decoded line #{iy}: #{image[iy].first(5)}... (showing first 5 pixels)"
      end
    end

    Rails.logger.info "ROD Parser: Successfully decoded #{ny} lines"

    # Flatten to 1D array for JSON serialization
    image.flatten
  end

  def decode_ty6_line_python(line_data, width)
    # Exact Python implementation from FormatROD.py decode_TY6_oneline

    linedata = line_data.bytes
    ipos = 0
    opos = 0
    ret = Array.new(width, 0)

    nblock = (width - 1) / (BLOCKSIZE * 2)
    nrest = (width - 1) % (BLOCKSIZE * 2)

    # Process first pixel (absolute value)
    firstpx = linedata[ipos]
    ipos += 1

    if firstpx < SHORT_OVERFLOW
      ret[opos] = firstpx - 127
    elsif firstpx == LONG_OVERFLOW
      if ipos + 3 < linedata.length
        ret[opos] = linedata[ipos, 4].pack("C*").unpack("l<")[0]
        ipos += 4
      end
    else
      if ipos + 1 < linedata.length
        ret[opos] = linedata[ipos, 2].pack("C*").unpack("s<")[0]
        ipos += 2
      end
    end
    opos += 1

    # Process blocks (this is the complex part with bit packing)
    (0...nblock).each do |k|
      break if ipos >= linedata.length

      bittype = linedata[ipos]
      nbits = [ bittype & 15, (bittype >> 4) & 15 ]
      ipos += 1

      (0...2).each do |i|
        nbit = nbits[i]
        zero_at = 0
        zero_at = (1 << (nbit - 1)) - 1 if nbit > 1

        v = 0
        (0...nbit).each do |j|
          break if ipos >= linedata.length
          v |= linedata[ipos] << (8 * j)
          ipos += 1
        end

        mask = (1 << nbit) - 1
        (0...BLOCKSIZE).each do |j|
          break if opos >= width
          ret[opos] = ((v >> (nbit * j)) & mask) - zero_at
          opos += 1
        end
      end

      # Apply differential encoding to the block just processed
      start_idx = opos - BLOCKSIZE * 2
      (start_idx...opos).each do |i|
        break if i <= 0 || i >= width

        offset = ret[i]
        if offset >= SHORT_OVERFLOW_SIGNED
          if offset >= LONG_OVERFLOW_SIGNED
            if ipos + 3 < linedata.length
              offset = linedata[ipos, 4].pack("C*").unpack("l<")[0]
              ipos += 4
            end
          else
            if ipos + 1 < linedata.length
              offset = linedata[ipos, 2].pack("C*").unpack("s<")[0]
              ipos += 2
            end
          end
        end
        ret[i] = offset + ret[i - 1]
      end
    end

    # Process remaining pixels
    (0...nrest).each do
      break if opos >= width || ipos >= linedata.length

      px = linedata[ipos]
      ipos += 1

      if px < SHORT_OVERFLOW
        ret[opos] = ret[opos - 1] + px - 127
      elsif px == LONG_OVERFLOW
        if ipos + 3 < linedata.length
          ret[opos] = ret[opos - 1] + linedata[ipos, 4].pack("C*").unpack("l<")[0]
          ipos += 4
        end
      else
        if ipos + 1 < linedata.length
          ret[opos] = ret[opos - 1] + linedata[ipos, 2].pack("C*").unpack("s<")[0]
          ipos += 2
        end
      end
      opos += 1
    end

    ret
  end

  def decode_uncompressed_image(nx, ny)
    Rails.logger.info "ROD Parser: Decoding uncompressed image (#{nx}x#{ny})"

    # Calculate the image data offset
    offset = 256
    general_nbytes = 512
    special_nbytes = 768
    km4gonio_nbytes = 1024
    statistics_nbytes = 512
    history_nbytes = 2048

    image_data_offset = offset + general_nbytes + special_nbytes + km4gonio_nbytes + statistics_nbytes + history_nbytes
    Rails.logger.info "ROD Parser: Image data starts at offset #{image_data_offset}"

    # Read raw pixel data (assuming 4 bytes per pixel for 32-bit integers)
    pixel_data_size = nx * ny * 4
    Rails.logger.info "ROD Parser: Reading #{pixel_data_size} bytes of pixel data"

    if image_data_offset + pixel_data_size > @image_data.bytesize
      Rails.logger.error "ROD Parser: Not enough data in file. Expected #{pixel_data_size} bytes at offset #{image_data_offset}, but file is only #{@image_data.bytesize} bytes"
      return Array.new(nx * ny, 0)  # Return zero array if data is insufficient
    end

    pixel_data = read_bytes(image_data_offset, pixel_data_size)

    # Unpack as 32-bit little-endian integers
    pixels = pixel_data.unpack("l<*")
    Rails.logger.info "ROD Parser: Successfully decoded #{pixels.length} pixels"
    pixels
  end

  def extract_metadata
    {
      binning: [ @header[:bin_x], @header[:bin_y] ],
      chip_dimensions: [ @header[:chip_npx_x], @header[:chip_npx_y] ],
      gain: @header[:gain],
      overflow_threshold: @header[:overflow_threshold],
      detector_distance_mm: @header[:distance_mm],
      beam_center_px: [ @header[:origin_px_x], @header[:origin_px_y] ],
      compression_type: @header[:compression_type]
    }
  end

  def read_bytes(offset, count)
    if offset + count > @image_data.bytesize
      raise "Attempted to read beyond file boundary: offset #{offset}, count #{count}, file size #{@image_data.bytesize}"
    end

    @image_data[offset, count]
  end
end
