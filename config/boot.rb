ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Load local environment variables from .env when present.
env_file = File.expand_path("../.env", __dir__)
if File.exist?(env_file)
  File.foreach(env_file) do |line|
    next if line.strip.empty? || line.start_with?("#")
    key, value = line.strip.split("=", 2)
    next unless key && value
    value = value.strip
    value = value[1..-2] if value.start_with?("\"") && value.end_with?("\"")
    value = value[1..-2] if value.start_with?("'") && value.end_with?("'")
    ENV[key] ||= value
  end
end

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
