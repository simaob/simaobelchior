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

  test "shows a glimpse of visits and game visits, linking to the full metrics" do
    3.times { |i| PageView.record(path: "/about", referrer: "https://github.com/", host: "www.example.com", ip: "203.0.113.#{i}", user_agent: "Chrome") }
    2.times { |i| PageView.record(path: "/palminho/", referrer: nil, host: PageView::GAMES_HOST, ip: "203.0.113.#{i}", user_agent: "Chrome") }
    post login_path, params: { email: "user1@example.com", password: "password" }

    get admin_root_url
    assert_select "#site-visits h2", "Visits"
    assert_select "#site-visits .visits-glimpse dd", text: "3", count: 3
    assert_select "#site-visits .visits-chart--small .visits-chart__day", 30
    assert_select "#site-visits .visits-chart__day:last-child[aria-label$=?]", "3 visits"
    assert_select "#site-visits a[href=?]", admin_site_visits_path

    assert_select "#game-visits h2", "Game visits"
    assert_select "#game-visits .visits-chart__day:last-child[aria-label$=?]", "2 visits"
    assert_select "#game-visits a[href=?]", admin_game_visits_path

    # The top pages and referrers are only on the full pages
    assert_select ".visits-table", count: 0
  end

  test "shows empty visit stats" do
    post login_path, params: { email: "user1@example.com", password: "password" }

    get admin_root_url
    assert_response :success
    assert_select "#site-visits .visits-glimpse dd", text: "0", count: 3
    assert_select "#game-visits .visits-chart__day", 30
  end
end
