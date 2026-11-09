require "test_helper"

class GameVisitsControllerTest < ActionDispatch::IntegrationTest
  CHROME = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"

  def open_game(path: "/palminho/", referrer: "https://simaobelchior.com/", origin: "https://games.simaobelchior.com", user_agent: CHROME)
    post game_visits_path, params: { path: path, referrer: referrer }, headers: { "Origin" => origin, "User-Agent" => user_agent }
  end

  test "counts a visit to a game" do
    open_game(path: "/behaving-in-public/games/buffer-zone/index.html")

    assert_response :no_content
    view = PageView.sole
    assert_equal "games.simaobelchior.com", view.host
    assert_equal "/behaving-in-public/games/buffer-zone/index.html", view.path
    assert_equal "simaobelchior.com", view.referrer_host
  end

  test "works without a CSRF token" do
    ActionController::Base.allow_forgery_protection = true
    open_game

    assert_response :no_content
    assert_equal 1, PageView.count
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "ignores requests from other sites, odd paths and bots" do
    open_game(origin: "https://example.com")
    open_game(origin: nil)
    open_game(path: "palminho")
    open_game(path: "/palminho/?q=<script>")
    open_game(path: "/#{"a" * 300}")
    open_game(user_agent: "curl/8.7.1")

    assert_response :no_content
    assert_equal 0, PageView.count
  end

  test "ignores a path sent as something other than text" do
    post game_visits_path, params: { path: { a: "/palminho/" } }, headers: { "Origin" => "https://games.simaobelchior.com", "User-Agent" => CHROME }

    assert_response :no_content
    assert_equal 0, PageView.count
  end

  test "doesn't count the site owner while logged in" do
    post login_path, params: { email: "user1@example.com", password: "password" }
    open_game

    assert_response :no_content
    assert_equal 0, PageView.count
  end
end
