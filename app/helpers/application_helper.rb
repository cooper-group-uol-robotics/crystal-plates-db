module ApplicationHelper
  def markdown(text)
    # Configure Redcarpet with options for code highlighting and tables
    renderer = Redcarpet::Render::HTML.new(
      filter_html: false,
      no_links: false,
      no_images: false,
      with_toc_data: true,
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener" }
    )

    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      space_after_headers: true,
      superscript: true,
      underline: true,
      highlight: true,
      quote: true
    )

    markdown.render(text).html_safe
  end

  # Format unit cell parameters for display, using conventional cell when available
  def format_unit_cell(dataset, show_bravais: true, precision: 3, angle_precision: 2)
    return nil unless dataset.has_primitive_cell?

    display_cell = dataset.display_cell
    return nil unless display_cell

    cell_params = [
      "a=#{number_with_precision(display_cell[:a], precision: precision)}Å",
      "b=#{number_with_precision(display_cell[:b], precision: precision)}Å",
      "c=#{number_with_precision(display_cell[:c], precision: precision)}Å",
      "α=#{number_with_precision(display_cell[:alpha], precision: angle_precision)}°",
      "β=#{number_with_precision(display_cell[:beta], precision: angle_precision)}°",
      "γ=#{number_with_precision(display_cell[:gamma], precision: angle_precision)}°"
    ].join(" ")

    if show_bravais && display_cell[:bravais].present?
      bravais_badge = content_tag(:span, display_cell[:bravais],
                                  class: "badge bg-secondary me-1")
      "#{bravais_badge}#{cell_params}".html_safe
    else
      cell_params
    end
  end

  # G6 comparison button for SCXRD datasets
  def g6_comparison_button(dataset, options = {})
    return "" unless dataset.has_primitive_cell?

    button_class = options[:class] || "btn btn-outline-info btn-sm"
    button_id = "g6-compare-#{dataset.id}"

    # Get the count of similar datasets (with default tolerance)
    similar_count = dataset.similar_datasets_count_by_g6

    if similar_count > 0
      button_text = content_tag(:i, "", class: "bi bi-box-seam me-1") +
                   "#{similar_count} similar unit cells"
      button_class += " has-matches"
    else
      button_text = content_tag(:i, "", class: "bi bi-box-seam me-1") +
                   "No similar unit cells"
    end

    content_tag(:button, button_text.html_safe,
                id: button_id,
                class: button_class,
                data: {
                  dataset_id: dataset.id,
                  bs_toggle: "modal",
                  bs_target: "#g6ComparisonModal"
                },
                onclick: "loadG6Comparison(#{dataset.id})")
  end
end
