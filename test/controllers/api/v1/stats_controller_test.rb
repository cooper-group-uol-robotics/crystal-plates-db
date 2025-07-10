require "test_helper"

class Api::V1::StatsControllerTest < ActionDispatch::IntegrationTest
  test "should get system statistics" do
    get api_v1_stats_url, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("data")

    data = json_response["data"]
    assert data.key?("overview")
    assert data.key?("locations")
    assert data.key?("plates")
    assert data.key?("wells")

    # Check overview stats
    overview = data["overview"]
    assert overview.key?("total_plates")
    assert overview.key?("total_locations")
    assert overview.key?("total_wells")
    assert overview.key?("occupied_locations")
    assert overview.key?("available_locations")

    # Verify numeric values
    assert overview["total_plates"].is_a?(Integer)
    assert overview["total_locations"].is_a?(Integer)
    assert overview["total_wells"].is_a?(Integer)
  end
end
