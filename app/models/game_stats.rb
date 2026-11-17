# How people get on with each level of each game over a period, from GameEvents: how
# many play it, how many finish, how many give up, and how well the finishers do.
# Players are counted like visits, once a day, so someone who comes back tomorrow
# counts again. For the admin's Games page.
#
# The games decide what they send. These numbers read the "started", "finished" and
# "left" events, and "moves", "par", "stars" and "hints" in their details. A "left"
# event with "after_finish" set is someone leaving a level they'd already finished.
class GameStats
  Level = Data.define(:name, :players, :finishers, :gave_up, :finishes, :median_moves, :par, :three_stars, :hints) do
    def finish_rate
      players.zero? ? nil : finishers.fdiv(players)
    end

    def three_star_rate
      finishes.zero? ? nil : three_stars.fdiv(finishes)
    end

    def hints_per_finish
      finishes.zero? ? nil : hints.fdiv(finishes)
    end
  end

  Game = Data.define(:slug, :players, :finishes, :levels) do
    def title
      slug.tr("-", " ").titleize
    end
  end

  Row = Data.define(:game, :level, :name, :visitor, :data)

  attr_reader :period

  def initialize(period: nil)
    @period = VisitStats::PERIODS.key?(period) ? period : VisitStats::DEFAULTS[:period]
  end

  # Same periods as the Visits page. All time starts at the first event, not the first
  # page view, so events from before any visit was counted aren't left out.
  def days
    @days ||= if period == "all"
      (GameEvent.minimum(:occurred_on) || Date.current)..Date.current
    else
      VisitStats.new(period: period, site: "games").days
    end
  end

  def games
    @games ||= rows.group_by(&:game).sort.map { |slug, game_rows| game_for(slug, game_rows) }
  end

  private

  def rows
    GameEvent.where(occurred_on: days).pluck(:game, :level, :name, :visitor_hash, :data).map do |game, level, name, visitor, data|
      Row.new(game: game, level: level, name: name, visitor: visitor, data: data.is_a?(Hash) ? data : {})
    end
  end

  def game_for(slug, game_rows)
    levels = game_rows.select(&:level).group_by(&:level).map { |name, level_rows| level_for(name, level_rows) }
    Game.new(
      slug: slug,
      players: game_rows.map(&:visitor).uniq.size,
      finishes: game_rows.count { |row| row.name == "finished" },
      levels: levels.sort_by { |level| natural_order(level.name) }
    )
  end

  def level_for(name, level_rows)
    finished = level_rows.select { |row| row.name == "finished" }
    finishers = finished.map(&:visitor).uniq
    quitters = level_rows.select { |row| row.name == "left" && !row.data["after_finish"] }.map(&:visitor).uniq - finishers

    Level.new(
      name: name,
      players: level_rows.map(&:visitor).uniq.size,
      finishers: finishers.size,
      gave_up: quitters.size,
      finishes: finished.size,
      median_moves: median(numbers(finished, "moves")),
      par: numbers(level_rows, "par").max,
      three_stars: finished.count { |row| row.data["stars"] == 3 },
      hints: numbers(finished, "hints").sum
    )
  end

  def numbers(rows, key)
    rows.map { |row| row.data[key] }.grep(Numeric)
  end

  def median(values)
    return nil if values.empty?

    sorted = values.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]).fdiv(2)
  end

  # "1-10" after "1-9", not after "1-1"
  def natural_order(name)
    name.scan(/\d+|\D+/).map { |part| part.match?(/\A\d+\z/) ? [ 0, part.to_i ] : [ 1, part ] }
  end
end
