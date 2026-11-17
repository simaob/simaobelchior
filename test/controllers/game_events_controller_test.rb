require "test_helper"

class GameEventsControllerTest < ActionDispatch::IntegrationTest
  CHROME = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"

  def send_event(game: "building-blobs", level: "2-4", name: "finished", data: { moves: 10, par: 10, stars: 3 }.to_json,
                 origin: "https://games.simaobelchior.com", user_agent: CHROME)
    post game_events_path, params: { game: game, level: level, name: name, data: data }.compact,
      headers: { "Origin" => origin, "User-Agent" => user_agent }
  end

  test "records an event from a game" do
    send_event

    assert_response :no_content
    event = GameEvent.sole
    assert_equal [ "building-blobs", "2-4", "finished" ], [ event.game, event.level, event.name ]
    assert_equal({ "moves" => 10, "par" => 10, "stars" => 3 }, event.data)
    assert_equal Date.current, event.occurred_on
    assert_match(/\A\h{64}\z/, event.visitor_hash)
  end

  test "an event needs no level" do
    send_event(level: nil, name: "opened_menu")

    assert_nil GameEvent.sole.level
  end

  test "works without a CSRF token" do
    ActionController::Base.allow_forgery_protection = true
    send_event

    assert_response :no_content
    assert_equal 1, GameEvent.count
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "ignores other sites, bots and badly named events" do
    send_event(origin: "https://example.com")
    send_event(origin: nil)
    send_event(user_agent: "curl/8.7.1")
    send_event(game: "Building Blobs")
    send_event(name: "<script>")
    send_event(level: "a" * 50)

    assert_response :no_content
    assert_equal 0, GameEvent.count
  end

  test "ignores names sent as something other than text" do
    post game_events_path, params: { game: { a: "x" }, name: "started" }, headers: { "Origin" => "https://games.simaobelchior.com", "User-Agent" => CHROME }

    assert_response :no_content
    assert_equal 0, GameEvent.count
  end

  test "keeps the event but drops details that aren't a small JSON object" do
    send_event(data: "not json")
    send_event(data: [ 1, 2 ].to_json)
    send_event(data: { note: "x" * 3000 }.to_json)

    assert_equal 3, GameEvent.count
    assert GameEvent.all.all? { |event| event.data == {} }
  end

  test "doesn't record the site owner while logged in" do
    post login_path, params: { email: "user1@example.com", password: "password" }
    send_event

    assert_equal 0, GameEvent.count
  end
end
