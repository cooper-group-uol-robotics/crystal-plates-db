# Configure WebAssembly MIME type for Propshaft

Rails.application.configure do
  # Add WASM files to be served with correct MIME type
  config.before_initialize do
    Rack::Mime::MIME_TYPES[".wasm"] = "application/wasm"
  end
end