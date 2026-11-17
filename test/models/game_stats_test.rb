require "test_helper"

class GameStatsTest < ActiveSupport::TestCase
  def event(name, level: "1-1", ip: "203.0.113.1", game: "building-blobs", **data)
    GameEvent.record(game: game, level: level, name: name, data: data.stringify_keys, ip: ip, user_agent: "Chrome")
  end

  test "counts players, finishers and people who gave up, per level" do
    event("started", ip: "203.0.113.1")
    event("finished", ip: "203.0.113.1", moves: 7, par: 6, stars: 2, hints: 1)
    event("started", ip: "203.0.113.2")
    event("left", ip: "203.0.113.2", moves: 3, par: 6)
    event("started", ip: "203.0.113.3")
    event("finished", ip: "203.0.113.3", moves: 6, par: 6, stars: 3, hints: 0)
    # Leaving a level after finishing it isn't giving up
    event("left", ip: "203.0.113.3", moves: 2, par: 6, after_finish: true)

    game = GameStats.new.games.sole
    assert_equal "Building Blobs", game.title
    assert_equal 3, game.players
    level = game.levels.sole
    assert_equal [ "1-1", 3, 2, 1, 2 ], [ level.name, level.players, level.finishers, level.gave_up, level.finishes ]
    assert_equal 6.5, level.median_moves
    assert_equal 6, level.par
    assert_in_delta 0.5, level.three_star_rate
    assert_in_delta 0.5, level.hints_per_finish
    assert_in_delta 2 / 3.0, level.finish_rate
  end

  test "someone who gave up and then finished the same day didn't give up" do
    event("left", moves: 4)
    event("finished", moves: 9, stars: 1)

    assert_equal 0, GameStats.new.games.sole.levels.sole.gave_up
  end

  test "levels come in natural order, games by name" do
    %w[1-10 2-1 1-2 1-9].each { |level| event("started", level: level) }
    event("started", game: "palminho", level: "segunda")

    games = GameStats.new.games
    assert_equal %w[building-blobs palminho], games.map(&:slug)
    assert_equal %w[1-2 1-9 1-10 2-1], games.first.levels.map(&:name)
  end

  test "words in started events are choices, as a share of level starts" do
    event("started", game: "palminho", level: "judo", kid: "tiago", lang: "pt")
    event("started", game: "palminho", level: "danca", kid: "tiago", lang: "pt")
    event("started", game: "palminho", level: "judo", ip: "203.0.113.2", kid: "ines", lang: "pt")
    event("finished", game: "palminho", level: "judo", kid: "clara", stars: 3)

    game = GameStats.new.games.sole
    assert_equal({ "kid" => [ [ "tiago", 2 / 3.0 ], [ "ines", 1 / 3.0 ] ], "lang" => [ [ "pt", 1.0 ] ] }, game.choices)
  end

  test "games without moves or hints don't get those columns" do
    event("started", game: "palminho", level: "judo")
    event("finished", game: "palminho", level: "judo", stars: 2)

    game = GameStats.new.games.sole
    assert_not game.moves?
    assert_not game.hints?
    assert_nil game.levels.sole.hints_per_finish
  end

  test "only counts the period asked for" do
    event("started")
    GameEvent.update_all(occurred_on: 40.days.ago.to_date)

    assert_empty GameStats.new(period: "30d").games
    assert_equal 1, GameStats.new(period: "90d").games.size
  end

  test "all time starts at the first event, even with no page views" do
    event("started")
    GameEvent.update_all(occurred_on: 3.years.ago.to_date)
    PageView.delete_all

    stats = GameStats.new(period: "all")
    assert_equal 3.years.ago.to_date, stats.days.first
    assert_equal 1, stats.games.size
  end
end
