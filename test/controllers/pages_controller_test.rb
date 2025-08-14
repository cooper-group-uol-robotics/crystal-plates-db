require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get pages_home_url
    assert_response :success
  end

  test "should get api docs" do
    get api_docs_url
    assert_response :success
    assert_select "h1", text: "API Documentation"
    assert_match "Crystal Plates Database REST API Documentation", response.body
  end
end
