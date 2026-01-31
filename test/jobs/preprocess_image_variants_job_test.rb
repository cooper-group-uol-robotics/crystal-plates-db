require "test_helper"

class PreprocessImageVariantsJobTest < ActiveJob::TestCase
  setup do
    @image = images(:one)
    # Ensure image has a file attached
    unless @image.file.attached?
      @image.file.attach(
        io: File.open(Rails.root.join("test", "fixtures", "files", "test_image.png")),
        filename: "test_image.png",
        content_type: "image/png"
      )
    end
  end

  test "preprocesses all variants for an image" do
    # Clear any existing variants
    @image.file.blob.variant_records.destroy_all

    # Run the job
    PreprocessImageVariantsJob.perform_now(@image.id)

    # Verify variants were created
    variants = @image.file.blob.variant_records.reload
    assert variants.count >= 3, "Expected at least 3 variants to be created"

    # Verify specific variants exist
    assert @image.file.variant(:thumb).key.present?, "Thumb variant should exist"
    assert @image.file.variant(:medium).key.present?, "Medium variant should exist"
    assert @image.file.variant(:large).key.present?, "Large variant should exist"
  end

  test "handles missing image gracefully" do
    assert_nothing_raised do
      PreprocessImageVariantsJob.perform_now(999999)
    end
  end

  test "handles image without file gracefully" do
    image_without_file = Image.create!(
      well: wells(:one),
      pixel_size_x_mm: 0.001,
      pixel_size_y_mm: 0.001,
      reference_x_mm: 0.0,
      reference_y_mm: 0.0,
      reference_z_mm: 0.0,
      pixel_width: 1000,
      pixel_height: 800
    )
    image_without_file.file.purge if image_without_file.file.attached?

    assert_nothing_raised do
      PreprocessImageVariantsJob.perform_now(image_without_file.id)
    end
  end

  test "job is queued when image is created" do
    well = wells(:one)
    
    assert_enqueued_with(job: PreprocessImageVariantsJob) do
      Image.create!(
        well: well,
        pixel_size_x_mm: 0.001,
        pixel_size_y_mm: 0.001,
        reference_x_mm: 0.0,
        reference_y_mm: 0.0,
        reference_z_mm: 0.0,
        pixel_width: 1000,
        pixel_height: 800,
        file: fixture_file_upload("test_image.png", "image/png")
      )
    end
  end

  test "retries on ActiveStorage::FileNotFoundError" do
    # Simulate file not found error
    Image.any_instance.stubs(:file).raises(ActiveStorage::FileNotFoundError)
    
    assert_performed_jobs 3 do
      perform_enqueued_jobs do
        PreprocessImageVariantsJob.perform_later(@image.id)
      end
    rescue ActiveStorage::FileNotFoundError
      # Expected after retries exhausted
    end
  end
end
