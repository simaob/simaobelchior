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

  test "shows visits" do
    3.times { |i| PageView.record(path: "/about", referrer: "https://github.com/", host: "www.example.com", ip: "203.0.113.#{i}", user_agent: "Chrome") }
    post login_path, params: { email: "user1@example.com", password: "password" }

    get admin_root_url
    assert_select ".visits-chart__day", 30
    assert_select ".visits-chart__day:last-child[aria-label$=?]", "3 visits"
    assert_select "td a[href='/about']", "/about"
    assert_select "td", "github.com"
  end

  test "shows empty visit stats" do
    post login_path, params: { email: "user1@example.com", password: "password" }

    get admin_root_url
    assert_response :success
    assert_select ".visits-chart__day", 30
    assert_select "p", "No page views yet."
  end
end
