class AutoSegmentationJob < ApplicationJob
  queue_as :segmentation

  def perform(image_id, well_id)
    @image = Image.find(image_id)
    @well = Well.find(well_id)

    Rails.logger.info "Starting auto-segmentation for image #{image_id}"

    # Call the segmentation service
    result = SegmentationApiService.segment_image(@image.file)

    if result[:error]
      Rails.logger.error "Auto-segmentation failed for image #{image_id}: #{result[:error]}"
      broadcast_error(result[:error])
    else
      segments_created = create_points_from_segments(result[:data])
      Rails.logger.info "Auto-segmentation completed for image #{image_id}: created #{segments_created} points"
      broadcast_success(result[:data], segments_created)
    end

  rescue StandardError => e
    Rails.logger.error "Auto-segmentation job failed for image #{image_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    broadcast_error("Job failed: #{e.message}")
  end

  private

  def create_points_from_segments(segmentation_data)
    created_points = []

    segmentation_data["segments"].each do |segment|
      centroid = segment["centroid"]

      point = @image.point_of_interests.create!(
        pixel_x: centroid["x"].round,
        pixel_y: centroid["y"].round,
        point_type: Setting.auto_segment_point_type,
        description: "Auto-segmented (confidence: #{segment['confidence'].round(3)})",
        marked_at: Time.current
      )

      created_points << {
        id: point.id,
        pixel_x: point.pixel_x,
        pixel_y: point.pixel_y,
        real_world_x_mm: point.real_world_x_mm,
        real_world_y_mm: point.real_world_y_mm,
        real_world_z_mm: point.real_world_z_mm,
        point_type: point.point_type,
        description: point.description,
        marked_at: point.marked_at,
        display_name: point.display_name
      }
    end

    created_points.length
  end

  def broadcast_success(segmentation_data, segments_created)
    # Broadcast success to the specific image channel
    ActionCable.server.broadcast(
      "auto_segmentation_#{@image.id}",
      {
        status: "completed",
        message: "Successfully created #{segments_created} points of interest",
        segments_created: segments_created,
        model_used: segmentation_data["model_used"],
        segments_found: segmentation_data["segments"].length,
        image_id: @image.id,
        well_id: @well.id
      }
    )
  end

  def broadcast_error(error_message)
    # Broadcast error to the specific image channel
    ActionCable.server.broadcast(
      "auto_segmentation_#{@image.id}",
      {
        status: "failed",
        error: error_message,
        image_id: @image.id,
        well_id: @well.id
      }
    )
  end
end
