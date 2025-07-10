require "test_helper"

class Api::V1::HealthControllerTest < ActionDispatch::IntegrationTest
  test "should get health status" do
    get api_v1_health_url, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("data")
    assert_equal "healthy", json_response["data"]["status"]
    assert json_response["data"].key?("timestamp")
    assert json_response["data"].key?("database")
    assert json_response["data"].key?("services")
  end
end
