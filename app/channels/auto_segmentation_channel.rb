class AutoSegmentationChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to a specific image's segmentation updates
    image_id = params[:image_id]
    stream_from "auto_segmentation_#{image_id}" if image_id.present?
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
