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

  test "only counts the period asked for" do
    event("started")
    GameEvent.update_all(occurred_on: 40.days.ago.to_date)

    assert_empty GameStats.new(period: "30d").games
    assert_equal 1, GameStats.new(period: "90d").games.size
  end
end
