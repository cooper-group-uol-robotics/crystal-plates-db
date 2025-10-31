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
    ].join("&nbsp;")

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

    button_class = options[:class] || "btn btn-outline-info btn-sm similarity-button"
    button_id = "similarity-btn-#{dataset.id}"

    # Initial loading state - similarity counts will be loaded by the Stimulus controller
    button_text = content_tag(:i, "", class: "bi bi-box-seam me-1") +
                 content_tag(:span, "Loading...", class: "similarity-text")

    # Determine modal target based on context (if we're in a well context, use the well-specific modal)
    modal_target = options[:well_context] ? "#wellG6ComparisonModal" : "#g6ComparisonModal"

    content_tag(:button, button_text.html_safe,
                id: button_id,
                class: button_class,
                type: "button",
                data: {
                  dataset_id: dataset.id,
                  g6_comparison_target: "similarityButton",
                  action: "click->g6-comparison#loadG6Comparison"
                })
  end

  # Helper method to determine CSS class for log lines based on content
  def log_line_class(line)
    case line
    when /ERROR/i
      "error"
    when /WARN/i
      "warn"
    when /DEBUG/i
      "debug"
    when /INFO/i
      "info"
    else
      "default"
    end
  end

  # Helper for styling processing log lines based on log level
  def log_level_badge_class(level)
    case level.to_s.downcase
    when /\berror\b/, /\bfatal\b/
      "danger"
    when /\bwarn\b/
      "warn"
    when /\binfo\b/
      "info"
    when /\bdebug\b/
      "debug"
    else
      "default"
    end
  end

  def time_duration_in_words(seconds)
    return "0s" if seconds <= 0
    
    if seconds < 60
      "#{seconds.round}s"
    elsif seconds < 3600
      minutes = (seconds / 60).round
      "#{minutes}m"
    else
      hours = (seconds / 3600).round(1)
      "#{hours}h"
    end
  end
end
