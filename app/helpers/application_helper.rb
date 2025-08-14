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
end
