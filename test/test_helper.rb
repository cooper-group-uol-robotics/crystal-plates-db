ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Helper to add API authentication headers
  def api_auth_headers(user = users(:writable))
    # Map user fixture to corresponding token
    # These must match the tokens used in api_keys.yml fixtures
    token_map = {
      users(:admin).id => "test_admin_token_1234567890abcdef",
      users(:writable).id => "test_writable_token_abcdef1234567890",
      users(:readable).id => "test_readable_token_fedcba0987654321"
    }

    token = token_map[user.id]

    # Verify the API key exists for this user
    unless user.api_keys.active.exists?
      raise "No active API key found for user #{user.email}. Check fixtures."
    end

    { "Authorization" => "Bearer #{token}" }
  end
end
