require "test_helper"

class Admin::GamesControllerTest < ActionDispatch::IntegrationTest
  def log_in
    post login_path, params: { email: "user1@example.com", password: "password" }
  end

  test "should redirect to login when not authenticated" do
    get admin_games_path
    assert_redirected_to login_path
  end

  test "shows each level's numbers" do
    GameEvent.record(game: "building-blobs", level: "2-4", name: "started", data: {}, ip: "203.0.113.1", user_agent: "Chrome")
    GameEvent.record(game: "building-blobs", level: "2-4", name: "finished", data: { "moves" => 10, "par" => 10, "stars" => 3, "hints" => 0 }, ip: "203.0.113.1", user_agent: "Chrome")
    log_in

    get admin_games_path
    assert_response :success
    assert_select "h1", "Games"
    assert_select "#game-building-blobs h2", "Building Blobs"
    assert_select "#game-building-blobs tbody tr", 1
    assert_select "#game-building-blobs tbody td", text: "10 / 10"
    assert_select "nav.admin-bar a[aria-current=page]", "Games"
  end

  test "shows which choices people make, and only the columns a game has" do
    GameEvent.record(game: "palminho", level: "judo", name: "started", data: { "kid" => "tiago" }, ip: "203.0.113.1", user_agent: "Chrome")
    GameEvent.record(game: "palminho", level: "judo", name: "finished", data: { "kid" => "tiago", "stars" => 3 }, ip: "203.0.113.1", user_agent: "Chrome")
    log_in

    get admin_games_path
    assert_response :success
    assert_select "#game-palminho .game-choice", /Kid:\s+tiago 100%/
    assert_select "#game-palminho th", text: "Moves / par", count: 0
    assert_select "#game-palminho th", text: "Hints per finish", count: 0
    assert_select "#game-palminho th", text: "★★★"
  end

  test "says when there's nothing yet" do
    log_in

    get admin_games_path(period: "7d")
    assert_response :success
    assert_select ".card-body", /No level events in this period/
  end
end
