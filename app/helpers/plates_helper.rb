module PlatesHelper
  # Well color coding based on content
  WELL_COLORS = {
    has_data: { bg_color: "#198754", text_color: "white" },  # Green - has images or PXRD patterns
    has_content: { bg_color: "#ffc107", text_color: "black" }, # Yellow - has stock solutions but no images/PXRD
    empty: { bg_color: "#dc3545", text_color: "white" }       # Red - empty
  }.freeze

  # Point type badge classes
  POINT_TYPE_BADGES = {
    "crystal" => "primary",
    "particle" => "secondary",
    "droplet" => "info"
  }.freeze

  def well_color_class(well)
    return WELL_COLORS[:has_data] if well.has_images? || well.has_pxrd_patterns?
    return WELL_COLORS[:has_content] if well.has_content?

    WELL_COLORS[:empty]
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
