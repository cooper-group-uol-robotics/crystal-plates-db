# Configure secure_headers for security best practices
SecureHeaders::Configuration.default do |config|
  # Content Security Policy
  config.csp = {
    default_src: %w['self'],
    script_src: %w['self' 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net https://unpkg.com],
    style_src: %w['self' 'unsafe-inline' https://cdn.jsdelivr.net],
    font_src: %w['self' https://cdn.jsdelivr.net data:],
    img_src: %w['self' data: https:],
    connect_src: %w['self'],
    frame_src: %w['none'],
    object_src: %w['none'],
    base_uri: %w['self'],
    form_action: %w['self']
  }

  # Referrer Policy
  config.referrer_policy = %w[origin-when-cross-origin strict-origin-when-cross-origin]

  # X-Frame-Options
  config.x_frame_options = "DENY"

  # X-Content-Type-Options
  config.x_content_type_options = "nosniff"

  # X-Download-Options
  config.x_download_options = "noopen"

  # X-Permitted-Cross-Domain-Policies
  config.x_permitted_cross_domain_policies = "none"

  # Clear-Site-Data (commented out, enable if needed)
  # config.clear_site_data = %w(cache cookies storage executionContexts)
end
