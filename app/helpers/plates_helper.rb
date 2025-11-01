module PlatesHelper
  # Dynamic layer system for well visualization
  WELL_LAYERS = {
    has_content: {
      name: "Has Content",
      description: "Wells containing chemicals or stock solutions",
      icon: "bi-droplet-fill",
      color: "#0d6efd",
      method: :has_content?
    },
    has_images: {
      name: "Has Images",
      description: "Wells with microscopy images",
      icon: "bi-camera-fill",
      color: "#198754",
      method: :has_images?
    },
    has_pxrd: {
      name: "Has PXRD",
      description: "Wells with powder X-ray diffraction data",
      icon: "bi-graph-up",
      color: "#fd7e14",
      method: :has_pxrd_patterns?
    },
    has_scxrd: {
      name: "Has SCXRD",
      description: "Wells with single crystal X-ray diffraction data",
      icon: "bi-gem",
      color: "#6f42c1",
      method: :has_scxrd_datasets?
    },
    unit_cells_db: {
      name: "Unique in DB",
      description: "Wells with SCXRD unit cells unique within our database",
      icon: "bi-database-fill",
      color: "#8e44ad",
      method: :has_db_unique_scxrd_unit_cell?
    },
    unit_cells_csd: {
      name: "Unique in CSD",
      description: "Wells with SCXRD unit cells unique within CSD",
      icon: "bi-gem",
      color: "#9b59b6",
      method: :has_csd_unique_scxrd_unit_cell?
    },
    has_calorimetry: {
      name: "Has Calorimetry",
      description: "Wells with calorimetry temperature data",
      icon: "bi-thermometer-half",
      color: "#dc3545",
      method: :has_calorimetry_datasets?
    }
  }.freeze

  # Point type badge classes
  POINT_TYPE_BADGES = {
    "crystal" => "primary",
    "particle" => "secondary",
    "droplet" => "info"
  }.freeze



  # New layer system methods
  def well_layer_data(well)
    # Return data for all layers for this well
    layer_data = {}

    WELL_LAYERS.each do |key, config|
      if key == :default
        # Use traditional color logic for default
        if well.has_images? || well.has_pxrd_patterns? || well.has_scxrd_datasets?
          layer_data[key] = { active: true, level: "has_data" }
        elsif well.has_content?
          layer_data[key] = { active: true, level: "has_content" }
        else
          layer_data[key] = { active: true, level: "empty" }
        end
      elsif config[:method]
        # Use the defined method to check if layer is active
        layer_data[key] = { active: well.send(config[:method]) }
      else
        layer_data[key] = { active: false }
      end
    end

    layer_data
  end

  def wells_data_for_layers(wells)
    # Serialize all wells data for JavaScript layer system
    wells_data = {}

    wells.each do |well|
      wells_data[well.id] = well_layer_data(well)
    end

    wells_data
  end

  def available_layers
    # Return layers configuration for UI
    WELL_LAYERS
  end

  def well_position_label(well)
    row_letter = ("A".ord + well.well_row - 1).chr
    label = "#{row_letter}#{well.well_column}"
    well.subwell > 1 ? "#{label}.#{well.subwell}" : label
  end

  def subwell_grid_columns(wells_count)
    wells_count <= 2 ? 1 : Math.sqrt(wells_count).ceil
  end

  def format_coordinates(real_x, real_y, reference_z_mm = nil)
    return content_tag(:span, "Not calibrated", class: "text-muted") unless real_x && real_y

    coords = sprintf("(%.3f, %.3f", real_x, real_y)
    coords += sprintf(", %.3f", reference_z_mm) if reference_z_mm
    coords + ")"
  end

  def point_type_badge_class(point_type)
    POINT_TYPE_BADGES[point_type] || "warning"
  end

  def format_marked_time(point)
    time = point.marked_at || point.created_at
    time&.strftime("%m/%d/%y %H:%M")
  end

  def plate_summary_stats(plate, wells, points_of_interest)
    {
      total_wells: wells.count,
      wells_with_content: wells.count(&:has_content?),
      wells_with_images: wells.count(&:has_images?),
      wells_with_pxrd: wells.count(&:has_pxrd_patterns?),
      total_points: points_of_interest.count
    }
  end

  def plate_action_buttons(plate)
    content_tag :div do
      concat link_to("Edit", edit_plate_path(plate), class: "btn btn-outline-primary me-2")
      concat button_to("Delete", plate_path(plate),
                      method: :delete,
                      class: "btn btn-outline-danger me-2",
                      form: { style: "display: inline-block;" },
                      data: { confirm: "Are you sure you want to delete Plate #{plate.barcode}? It can be restored later." })
      concat link_to("Back", plates_path, class: "btn btn-outline-secondary")
    end
  end

  def well_tooltip_text(well)
    status_parts = []
    status_parts << "Has images" if well.has_images?
    status_parts << "Has PXRD" if well.has_pxrd_patterns?
    status_parts << "Has content" if well.has_content?
    status_parts << "Empty" if status_parts.empty?

    "#{well.well_label_with_subwell}: #{status_parts.join(', ')}"
  end
end
