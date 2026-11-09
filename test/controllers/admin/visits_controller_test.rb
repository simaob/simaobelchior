require "test_helper"

class Admin::VisitsControllerTest < ActionDispatch::IntegrationTest
  def log_in
    post login_path, params: { email: "user1@example.com", password: "password" }
  end

  test "should redirect to login when not authenticated" do
    get admin_site_visits_path
    assert_redirected_to login_path

    get admin_game_visits_path
    assert_redirected_to login_path
  end

  test "shows all the site's visit stats" do
    3.times { |i| PageView.record(path: "/about", referrer: "https://github.com/", host: "www.example.com", ip: "203.0.113.#{i}", user_agent: "Chrome") }
    log_in

    get admin_site_visits_path
    assert_response :success
    assert_select "title", /\AVisits/
    assert_select "h1", "Visits"
    assert_select "#site-visits .visits-chart__day", 30
    assert_select "#site-visits .visits-chart__day:last-child[aria-label$=?]", "3 visits"
    assert_select "#site-visits td a[href='/about']", "/about"
    assert_select "#site-visits td", "github.com"
  end

  test "shows game visits apart from the site's" do
    PageView.record(path: "/about", referrer: nil, host: "www.example.com", ip: "203.0.113.1", user_agent: "Chrome")
    2.times { |i| PageView.record(path: "/palminho/", referrer: "https://simaobelchior.com/", host: PageView::GAMES_HOST, ip: "203.0.113.#{i}", user_agent: "Chrome") }
    log_in

    get admin_game_visits_path
    assert_response :success
    assert_select "h1", "Game visits"
    assert_select "#game-visits .visits-chart__day:last-child[aria-label$=?]", "2 visits"
    assert_select "#game-visits td a[href=?]", "https://games.simaobelchior.com/palminho/", "/palminho/"
    assert_select "#game-visits td", "simaobelchior.com"
    assert_select "#game-visits td a", text: "/about", count: 0

    get admin_site_visits_path
    assert_select "#site-visits .visits-chart__day:last-child[aria-label$=?]", "1 visit"
    assert_select "#site-visits td a", "/about"
  end

  test "shows empty visit stats" do
    log_in

    [ [ admin_site_visits_path, "#site-visits" ], [ admin_game_visits_path, "#game-visits" ] ].each do |path, id|
      get path
      assert_response :success
      assert_select "#{id} .visits-chart__day", 30
      assert_select "#{id} p", "No page views yet."
      assert_select "#{id} p", "No visits from other sites yet."
    end
  end
end
