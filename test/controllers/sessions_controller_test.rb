require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get login page" do
    get login_path
    assert_response :success
  end

  test "should login with valid credentials" do
    post login_path, params: { email: "user1@example.com", password: "password" }
    assert_redirected_to admin_root_path
    assert_equal users(:one).id, session[:user_id]
  end

  test "should not login with invalid credentials" do
    post login_path, params: { email: "user1@example.com", password: "wrong" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "should logout" do
    # Login first
    post login_path, params: { email: "user1@example.com", password: "password" }
    assert session[:user_id].present?

    # Then logout
    delete logout_path
    assert_redirected_to root_path
    assert_nil session[:user_id]
  end
end
