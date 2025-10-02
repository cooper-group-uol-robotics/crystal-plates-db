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
end
