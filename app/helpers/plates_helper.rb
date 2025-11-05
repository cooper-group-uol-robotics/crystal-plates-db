module PlatesHelper
  # Dynamic layer system for well visualization
  # Using matplotlib tab10 colormap for optimal data visualization
  WELL_LAYERS = {
    has_content: {
      name: "Has Content",
      description: "Wells containing chemicals or stock solutions",
      icon: "bi-droplet-fill",
      color: "#1f77b4", # tab10 blue
      method: :has_content?
    },
    has_images: {
      name: "Has Images",
      description: "Wells with microscopy images",
      icon: "bi-camera-fill",
      color: "#ff7f0e", # tab10 orange
      method: :has_images?
    },
    has_pxrd: {
      name: "Has PXRD",
      description: "Wells with powder X-ray diffraction data",
      icon: "bi-graph-up",
      color: "#2ca02c", # tab10 green
      method: :has_pxrd_patterns?
    },
    has_calorimetry: {
      name: "Has Calorimetry",
      description: "Wells with calorimetry temperature data",
      icon: "bi-thermometer-half",
      color: "#9467bd", # tab10 purple
      method: :has_calorimetry_datasets?
    },
    has_scxrd: {
      name: "Has SCXRD",
      description: "Wells with single crystal X-ray diffraction data",
      icon: "bi-gem",
      color: "#d62728", # tab10 red
      method: :has_scxrd_datasets?
    },
    unit_cells_db: {
      name: "Unique in DB",
      description: "Wells with SCXRD unit cells unique within our database",
      icon: "bi-database-fill",
      color: "#8c564b", # tab10 brown
      method: :has_db_unique_scxrd_unit_cell?
    },
    unit_cells_csd: {
      name: "Unique in CSD",
      description: "Wells with SCXRD unit cells unique within CSD",
      icon: "bi-database-fill",
      color: "#e377c2", # tab10 pink
      method: :has_csd_unique_scxrd_unit_cell?
    },
    csd_formula_matches: {
      name: "CSD with Formula",
      description: "Wells with SCXRD datasets that have both unit cell and chemical formula matches in CSD",
      icon: "bi-diagram-3-fill",
      color: "#17a2b8", # tab10 cyan/teal
      method: :has_csd_formula_matches?
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
      # Convert symbol keys to strings for JSON compatibility
      string_key = key.to_s

      if config[:method]
        # Use the defined method to check if layer is active
        layer_data[string_key] = { active: well.send(config[:method]) }
      else
        layer_data[string_key] = { active: false }
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
    # Return layers configuration for UI with string keys for JSON compatibility
    WELL_LAYERS.transform_keys(&:to_s)
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
    tooltip_parts = [ "#{well.well_label_with_subwell}" ]

    # Content information with specific names
    if well.has_content?
      content_details = []

      # Add chemical names - use loaded associations when available
      chemicals = if well.association(:chemicals).loaded?
                    well.chemicals.to_a
                  else
                    well.chemicals.to_a
                  end
      
      if chemicals.any?
        chemical_names = chemicals.first(3).map(&:name)
        if chemicals.size > 3
          chemical_names << "#{chemicals.size - 3} more..."
        end
        content_details += chemical_names.map { |name| "Chemical: #{name}" }
      end

      # Add stock solution names - use loaded associations when available
      direct_stock_solutions = if well.association(:stock_solutions).loaded?
                                 well.stock_solutions.to_a
                               else
                                 well.stock_solutions.to_a
                               end
      
      polymorphic_stock_solutions = if well.association(:polymorphic_stock_solutions).loaded?
                                     well.polymorphic_stock_solutions.to_a
                                   else
                                     well.polymorphic_stock_solutions.to_a
                                   end
      
      stock_solutions = (direct_stock_solutions + polymorphic_stock_solutions).uniq
      if stock_solutions.any?
        stock_names = stock_solutions.first(3).map(&:display_name)
        if stock_solutions.size > 3
          stock_names << "#{stock_solutions.size - 3} more..."
        end
        content_details += stock_names.map { |name| "Stock: #{name}" }
      end

      if content_details.any?
        tooltip_parts += content_details
      else
        tooltip_parts << "Has content"
      end
    end

    # Image data with count
    if well.has_images?
      image_count = well.images.count
      tooltip_parts << "#{image_count} image#{'s' if image_count != 1}"
    end

    # PXRD data with count
    if well.has_pxrd_patterns?
      pxrd_count = well.pxrd_patterns.count
      tooltip_parts << "#{pxrd_count} PXRD pattern#{'s' if pxrd_count != 1}"
    end

    # SCXRD data with details
    if well.has_scxrd_datasets?
      scxrd_count = well.scxrd_datasets.count
      tooltip_parts << "#{scxrd_count} SCXRD dataset#{'s' if scxrd_count != 1}"

      # Add unit cell info if available
      if well.has_scxrd_unit_cell?
        tooltip_parts << "  - Has unit cell parameters"

        if well.has_db_unique_scxrd_unit_cell?
          tooltip_parts << "  - Unique in database"
        end

        if well.has_csd_unique_scxrd_unit_cell?
          tooltip_parts << "  - Unique in CSD"
        end
      end
    end

    # Calorimetry data with count
    if well.has_calorimetry_datasets?
      calorimetry_count = well.calorimetry_datasets.count
      tooltip_parts << "#{calorimetry_count} calorimetry dataset#{'s' if calorimetry_count != 1}"
    end

    # If completely empty
    if tooltip_parts.size == 1
      tooltip_parts << "Empty well"
    end

    tooltip_parts.join("\n")
  end
end
