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
    assert_select "#site-visits .visits-chart__day", 30
    assert_select "#site-visits .visits-chart__day:last-child[aria-label$=?]", "3 visits"
    assert_select "#site-visits td a[href='/about']", "/about"
    assert_select "#site-visits td", "github.com"
  end

  test "shows game visits apart from the site's" do
    PageView.record(path: "/about", referrer: nil, host: "www.example.com", ip: "203.0.113.1", user_agent: "Chrome")
    2.times { |i| PageView.record(path: "/palminho/", referrer: "https://simaobelchior.com/", host: PageView::GAMES_HOST, ip: "203.0.113.#{i}", user_agent: "Chrome") }
    post login_path, params: { email: "user1@example.com", password: "password" }

    get admin_root_url
    assert_select "#site-visits h2", "Visits"
    assert_select "#site-visits .visits-chart__day:last-child[aria-label$=?]", "1 visit"
    assert_select "#game-visits h2", "Game visits"
    assert_select "#game-visits .visits-chart__day:last-child[aria-label$=?]", "2 visits"
    assert_select "#game-visits td a[href=?]", "https://games.simaobelchior.com/palminho/", "/palminho/"
    assert_select "#game-visits td", "simaobelchior.com"
    assert_select "#site-visits td a", "/about"
  end

  test "shows empty visit stats" do
    post login_path, params: { email: "user1@example.com", password: "password" }

    get admin_root_url
    assert_response :success
    assert_select "#site-visits .visits-chart__day", 30
    assert_select "#game-visits .visits-chart__day", 30
    assert_select "#site-visits p", "No page views yet."
    assert_select "#game-visits p", "No page views yet."
  end
end
