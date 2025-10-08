require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should redirect to login when not authenticated" do
    get admin_root_url
    assert_redirected_to login_path
  end

  test "should get index when authenticated" do
    # Login first
    post login_path, params: { email: "user1@example.com", password: "password" }

    get admin_root_url
    assert_response :success
  end
end
