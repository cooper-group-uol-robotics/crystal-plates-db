# Be sure to restart your server when you modify this file.

# Propshaft configuration for CSS assets
# JavaScript is handled by importmap-rails

# Configure WebAssembly MIME type for proper serving
Rails.application.config.before_initialize do
  Rack::Mime::MIME_TYPES[".wasm"] = "application/wasm"
end

# Note: WASM files are served directly from public/wasm/
# Note: JavaScript is handled entirely by importmap-rails
