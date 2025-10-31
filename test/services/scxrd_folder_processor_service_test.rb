require "test_helper"
require "tempfile"
require "fileutils"

class ScxrdFolderProcessorServiceTest < ActiveSupport::TestCase
  def setup
    @temp_dir = Dir.mktmpdir
    @expinfo_dir = File.join(@temp_dir, "expinfo")
    FileUtils.mkdir_p(@expinfo_dir)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  test "calculates well image reference point from crystal center coordinates" do
    # Test coordinates from center to top-left conversion
    crystal_center_x = 10.0   # mm
    crystal_center_y = 20.0   # mm
    crystal_center_z = 5.0    # mm
    pixel_width = 1000        # pixels
    pixel_height = 800        # pixels
    pixel_size = 0.000874     # mm/pixel (as specified in requirements)

    result = ScxrdFolderProcessorService.calculate_well_image_reference_point(
      crystal_center_x, crystal_center_y, crystal_center_z,
      pixel_width, pixel_height, pixel_size
    )

    # Calculate expected values
    half_width_mm = (pixel_width * pixel_size) / 2.0  # (1000 * 0.000874) / 2 = 0.437
    half_height_mm = (pixel_height * pixel_size) / 2.0  # (800 * 0.000874) / 2 = 0.3496

    expected_ref_x = crystal_center_x - half_width_mm  # 10.0 - 0.437 = 9.563
    expected_ref_y = crystal_center_y - half_height_mm  # 20.0 - 0.3496 = 19.6504

    assert_not_nil result
    assert_equal expected_ref_x, result[:reference_x_mm]
    assert_equal expected_ref_y, result[:reference_y_mm]
    assert_equal crystal_center_z, result[:reference_z_mm]
    assert_equal pixel_size, result[:pixel_size_x_mm]
    assert_equal pixel_size, result[:pixel_size_y_mm]
  end

  test "parses reduced cell from crystal.ini file correctly" do
    # Create a sample crystal.ini file with reduced cell data
    crystal_ini_content = <<~INI
      [General]
      version=1.0

      [Crystal]
      reduced cell plus vol=7.2218583  8.5410638 8.5902173 107.6582105 91.8679754 90.9411566 504.4382028

      [Other]
      some_other_data=value
    INI

    crystal_ini_path = File.join(@expinfo_dir, "test_crystal.ini")
    File.write(crystal_ini_path, crystal_ini_content)

    service = ScxrdFolderProcessorService.new(@temp_dir)

    # Call the private method directly for testing
    result = service.send(:parse_crystal_ini_file, crystal_ini_path)

    assert_not_nil result
    assert_equal 7.2218583, result[:a]
    assert_equal 8.5410638, result[:b]
    assert_equal 8.5902173, result[:c]
    assert_equal 107.6582105, result[:alpha]
    assert_equal 91.8679754, result[:beta]
    assert_equal 90.9411566, result[:gamma]
  end

  test "handles missing reduced cell line gracefully" do
    # Create a crystal.ini file without reduced cell data
    crystal_ini_content = <<~INI
      [General]
      version=1.0

      [Crystal]
      some_other_line=value

      [Other]
      some_other_data=value
    INI

    crystal_ini_path = File.join(@expinfo_dir, "test_crystal.ini")
    File.write(crystal_ini_path, crystal_ini_content)

    service = ScxrdFolderProcessorService.new(@temp_dir)
    result = service.send(:parse_crystal_ini_file, crystal_ini_path)

    assert_nil result
  end

  test "handles malformed reduced cell line gracefully" do
    # Create a crystal.ini file with malformed reduced cell data
    crystal_ini_content = <<~INI
      [General]
      version=1.0

      [Crystal]
      reduced cell plus vol=invalid data here

      [Other]
      some_other_data=value
    INI

    crystal_ini_path = File.join(@expinfo_dir, "test_crystal.ini")
    File.write(crystal_ini_path, crystal_ini_content)

    service = ScxrdFolderProcessorService.new(@temp_dir)
    result = service.send(:parse_crystal_ini_file, crystal_ini_path)

    assert_nil result
  end

  test "handles insufficient numbers in reduced cell line" do
    # Create a crystal.ini file with insufficient reduced cell data
    crystal_ini_content = <<~INI
      [General]
      version=1.0

      [Crystal]
      reduced cell plus vol=7.2218583  8.5410638 8.5902173

      [Other]
      some_other_data=value
    INI

    crystal_ini_path = File.join(@expinfo_dir, "test_crystal.ini")
    File.write(crystal_ini_path, crystal_ini_content)

    service = ScxrdFolderProcessorService.new(@temp_dir)
    result = service.send(:parse_crystal_ini_file, crystal_ini_path)

    assert_nil result
  end

  test "handles missing crystal.ini file gracefully" do
    service = ScxrdFolderProcessorService.new(@temp_dir)
    result = service.send(:parse_crystal_ini_file, File.join(@expinfo_dir, "nonexistent.ini"))

    assert_nil result
  end

  test "prioritizes crystal.ini over par files" do
    # Create both crystal.ini and par files
    crystal_ini_content = <<~INI
      [Crystal]
      reduced cell plus vol=7.2218583  8.5410638 8.5902173 107.6582105 91.8679754 90.9411566 504.4382028
    INI

    par_content = <<~PAR
      CELL INFORMATION
      10.123(0.001) 11.456(0.002) 12.789(0.003)
      90.000(0.100) 95.123(0.200) 100.456(0.300)
    PAR

    crystal_ini_path = File.join(@expinfo_dir, "test_crystal.ini")
    par_path = File.join(@temp_dir, "test.par")

    File.write(crystal_ini_path, crystal_ini_content)
    File.write(par_path, par_content)

    service = ScxrdFolderProcessorService.new(@temp_dir)
    result = service.process

    # Should use crystal.ini values, not par file values
    assert_not_nil result[:metadata]
    assert_equal 7.2218583, result[:metadata][:a]
    assert_equal 8.5410638, result[:metadata][:b]
    assert_equal 8.5902173, result[:metadata][:c]
  end

  test "parses coordinates from cmdscript.mac file" do
    # Create test files
    Dir.mktmpdir do |temp_dir|
      cmdscript_file = File.join(temp_dir, "cmdscript.mac")
      File.write(cmdscript_file, "xx xtalcheck move x 48.25 y 1.33 z 0.08\n")

      service = ScxrdFolderProcessorService.new(temp_dir)
      coordinates = service.send(:parse_cmdscript_coordinates)

      assert_not_nil coordinates
      assert_equal 48.25, coordinates[:real_world_x_mm]
      assert_equal 1.33, coordinates[:real_world_y_mm]
      assert_equal 0.08, coordinates[:real_world_z_mm]
    end
  end

  test "handles missing cmdscript.mac file gracefully" do
    Dir.mktmpdir do |temp_dir|
      service = ScxrdFolderProcessorService.new(temp_dir)
      coordinates = service.send(:parse_cmdscript_coordinates)

      assert_nil coordinates
    end
  end

  test "handles malformed cmdscript.mac file gracefully" do
    Dir.mktmpdir do |temp_dir|
      cmdscript_file = File.join(temp_dir, "cmdscript.mac")
      File.write(cmdscript_file, "invalid format line\n")

      service = ScxrdFolderProcessorService.new(temp_dir)
      coordinates = service.send(:parse_cmdscript_coordinates)

      assert_nil coordinates
    end
  end

  test "integrates crystal.ini and cmdscript.mac parsing" do
    Dir.mktmpdir do |temp_dir|
      # Create expinfo directory and crystal.ini file
      expinfo_dir = File.join(temp_dir, "expinfo")
      Dir.mkdir(expinfo_dir)

      crystal_ini_file = File.join(expinfo_dir, "test_crystal.ini")
      File.write(crystal_ini_file, <<~CONTENT)
        [Some Section]
        other_param=value
        reduced cell plus vol=7.2218583  8.5410638 8.5902173 107.6582105 91.8679754 90.9411566 504.4382028
        more_content=here
      CONTENT

      # Create cmdscript.mac file
      cmdscript_file = File.join(temp_dir, "cmdscript.mac")
      File.write(cmdscript_file, "xx xtalcheck move x 48.25 y 1.33 z 0.08\n")

      service = ScxrdFolderProcessorService.new(temp_dir)
      result = service.process

      assert_not_nil result[:metadata]

      # Check unit cell parameters
      assert_equal 7.2218583, result[:metadata][:a]
      assert_equal 8.5410638, result[:metadata][:b]
      assert_equal 8.5902173, result[:metadata][:c]
      assert_equal 107.6582105, result[:metadata][:alpha]
      assert_equal 91.8679754, result[:metadata][:beta]
      assert_equal 90.9411566, result[:metadata][:gamma]

      # Check real world coordinates
      assert_equal 48.25, result[:metadata][:real_world_x_mm]
      assert_equal 1.33, result[:metadata][:real_world_y_mm]
      assert_equal 0.08, result[:metadata][:real_world_z_mm]
    end
  end

  test "coordinates with negative values parsed correctly" do
    Dir.mktmpdir do |temp_dir|
      cmdscript_file = File.join(temp_dir, "cmdscript.mac")
      File.write(cmdscript_file, "xx xtalcheck move x -12.75 y 45.2 z -3.14\n")

      service = ScxrdFolderProcessorService.new(temp_dir)
      coordinates = service.send(:parse_cmdscript_coordinates)

      assert_not_nil coordinates
      assert_equal(-12.75, coordinates[:real_world_x_mm])
      assert_equal 45.2, coordinates[:real_world_y_mm]
      assert_equal(-3.14, coordinates[:real_world_z_mm])
    end
  end
end
