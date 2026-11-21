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

  test "login without remember me does not survive the browser session ending" do
    post login_path, params: { email: "user1@example.com", password: "password", remember_me: "0" }
    assert cookies[:remember_me].blank?

    end_browser_session
    get admin_root_path
    assert_redirected_to login_path
  end

  test "remember me keeps you logged in after the browser session ends" do
    post login_path, params: { email: "user1@example.com", password: "password", remember_me: "1" }
    assert cookies[:remember_me].present?

    end_browser_session
    get admin_root_path
    assert_response :success
  end

  test "remember me expires after 4 weeks" do
    post login_path, params: { email: "user1@example.com", password: "password", remember_me: "1" }
    token = cookies[:remember_me]

    travel 4.weeks + 1.minute do
      end_browser_session
      cookies[:remember_me] = token
      get admin_root_path
      assert_redirected_to login_path
    end
  end

  test "changing the password invalidates remember me" do
    post login_path, params: { email: "user1@example.com", password: "password", remember_me: "1" }
    users(:one).update!(password: "a-new-password")

    end_browser_session
    get admin_root_path
    assert_redirected_to login_path
    assert cookies[:remember_me].blank?
  end

  test "logout clears remember me" do
    post login_path, params: { email: "user1@example.com", password: "password", remember_me: "1" }
    delete logout_path
    assert cookies[:remember_me].blank?

    end_browser_session
    get admin_root_path
    assert_redirected_to login_path
  end

  private

  # Simulates the browser discarding its session cookie (e.g. a mobile browser
  # being closed), while keeping any persistent cookies.
  def end_browser_session
    cookies.delete(Rails.application.config.session_options[:key])
  end
end
