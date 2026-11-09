# One public page served to a person, counted on the server. Nothing is stored
# in the visitor's browser and no IP address or user agent is kept, which is why
# the site needs no cookie banner.
#
# A visit is one person on one day. The visitor hash combines IP address and
# user agent with that day's salt (see VisitorSalt), so the same person counts
# once a day and can't be followed from one day to the next.
#
# The games on games.simaobelchior.com are counted here too, see GameVisitsController.
# Their views are kept apart from this site's by host.
class PageView < ApplicationRecord
  GAMES_HOST = "games.simaobelchior.com"

  Day = Data.define(:day, :visits, :views)
  Summary = Data.define(:days, :top_pages, :top_referrers)

  scope :games, -> { where(host: GAMES_HOST) }
  scope :site, -> { where.not(host: GAMES_HOST) }

  BOT_USER_AGENT = /
    bot|crawl|spider|slurp|scrap|archiv|fetch|preview|monitor|uptime|lighthouse|headless|
    curl|wget|httpie|python|ruby|perl|go-http|java\/|okhttp|axios|node|
    facebookexternalhit|whatsapp|mastodon|cardyb|chatgpt|perplexity|claude|googleother|-ai\b
  /xi

  def self.record(path:, referrer:, host:, ip:, user_agent:)
    day = Date.current

    create!(
      host: bare_host(host),
      path: path,
      referrer_host: external_host(referrer, host),
      visitor_hash: OpenSSL::HMAC.hexdigest("SHA256", VisitorSalt.for(day), "#{ip}|#{user_agent}"),
      visited_on: day
    )
  end

  def self.bot?(user_agent)
    user_agent.blank? || user_agent.match?(BOT_USER_AGENT)
  end

  # Only keep where people came from, not clicks between pages on the same site
  def self.external_host(referrer, own_host)
    host = bare_host(URI.parse(referrer.to_s).host)
    host unless host.nil? || host == bare_host(own_host)
  rescue URI::InvalidURIError
    nil
  end

  def self.bare_host(host)
    host.to_s.downcase.delete_prefix("www.").presence
  end

  # Visits per day, top pages and top referrers, for the last few days
  def self.summary(days: 30)
    per_day = by_day(days: days)
    since = per_day.first.day

    Summary.new(days: per_day, top_pages: top_pages(since: since), top_referrers: top_referrers(since: since))
  end

  # Visits and page views for each of the last few days, oldest first,
  # including days with none
  def self.by_day(days: 30)
    range = (Date.current - (days - 1))..Date.current
    scope = where(visited_on: range).group(:visited_on)
    visits = scope.distinct.count(:visitor_hash)
    views = scope.count

    range.map { |day| Day.new(day: day, visits: visits.fetch(day, 0), views: views.fetch(day, 0)) }
  end

  def self.top_pages(since:, limit: 10)
    where(visited_on: since..)
      .group(:path)
      .order(Arel.sql("COUNT(*) DESC"), :path)
      .limit(limit)
      .count
  end

  def self.top_referrers(since:, limit: 10)
    where(visited_on: since..)
      .where.not(referrer_host: nil)
      .group(:referrer_host)
      .order(Arel.sql("COUNT(DISTINCT visitor_hash) DESC"), :referrer_host)
      .limit(limit)
      .distinct
      .count(:visitor_hash)
  end
end
