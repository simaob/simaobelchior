require "test_helper"

class GameEventTest < ActiveSupport::TestCase
  test "keeps flat numbers, true or false and short words" do
    data = { "moves" => 12, "time" => 3.14159, "after_finish" => true, "mode" => "hard" }

    assert_equal({ "moves" => 12, "time" => 3.14, "after_finish" => true, "mode" => "hard" }, GameEvent.clean(data))
  end

  test "drops anything that could carry more than that" do
    data = {
      "nested" => { "a" => 1 },
      "list" => [ 1, 2 ],
      "email" => "someone@example.com",
      "long" => "x" * 41,
      "Bad Key" => 1,
      "huge" => 10**12,
      "nan" => Float::NAN
    }

    assert_equal({ "huge" => GameEvent::BIGGEST }, GameEvent.clean(data))
    assert_equal({}, GameEvent.clean("moves=3"))
  end

  test "keeps at most a dozen details" do
    data = (1..20).to_h { |i| [ "k#{"x" * i}", i ] }

    assert_equal GameEvent::MAX_DETAILS, GameEvent.clean(data).size
  end

  test "one person gets the same visitor hash as their page views that day" do
    event = GameEvent.record(game: "palminho", level: nil, name: "started", data: {}, ip: "203.0.113.9", user_agent: "Chrome")
    view = PageView.record(path: "/palminho/", referrer: nil, host: PageView::GAMES_HOST, ip: "203.0.113.9", user_agent: "Chrome")

    assert_equal view.visitor_hash, event.visitor_hash
  end

  test "quietly drops an event with a bad game name" do
    event = GameEvent.record(game: "../etc", level: nil, name: "started", data: {}, ip: "203.0.113.9", user_agent: "Chrome")

    assert_not event.persisted?
  end
end
