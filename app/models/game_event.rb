# Something that happened in one of the games on games.simaobelchior.com, like a level
# started, finished or left, so you can see which levels people finish and which they
# give up on. See GameStats.
#
# Kept like a PageView: no cookies, no IP address and no user agent, only the same
# daily visitor hash. The details are whatever few numbers and short words the game
# sends (moves, stars, hints...), cleaned so nothing else can be stored.
class GameEvent < ApplicationRecord
  SLUG = /\A[a-z0-9][a-z0-9\-]{0,39}\z/
  LEVEL = /\A[\w\-.]{1,40}\z/
  NAME = /\A[a-z][a-z_]{0,29}\z/
  DATA_KEY = /\A[a-z][a-z_]{0,29}\z/
  DATA_WORD = /\A[\w\-. ]{1,40}\z/
  MAX_DETAILS = 12
  BIGGEST = 1_000_000

  validates :game, format: { with: SLUG }
  validates :name, format: { with: NAME }
  validates :level, format: { with: LEVEL }, allow_nil: true

  # Saves the event if it's well formed, and quietly drops it if it isn't
  def self.record(game:, level:, name:, data:, ip:, user_agent:)
    day = Date.current
    create(
      game: game,
      level: level,
      name: name,
      data: clean(data),
      visitor_hash: PageView.visitor_hash(day, ip, user_agent),
      occurred_on: day
    )
  end

  # Keeps flat numbers, true or false, and short words, up to MAX_DETAILS of them
  def self.clean(data)
    return {} unless data.is_a?(Hash)

    data.each_with_object({}) do |(key, value), kept|
      break kept if kept.size >= MAX_DETAILS
      next unless key.is_a?(String) && key.match?(DATA_KEY)

      case value
      when Integer then kept[key] = value.clamp(-BIGGEST, BIGGEST)
      when Float then kept[key] = value.clamp(-BIGGEST, BIGGEST).round(2) if value.finite?
      when true, false then kept[key] = value
      when String then kept[key] = value if value.match?(DATA_WORD)
      end
    end
  end
end
