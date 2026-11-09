# One public page served to a person, counted on the server. Nothing is stored
# in the visitor's browser and no IP address or user agent is kept, which is why
# the site needs no cookie banner.
#
# A visit is one person on one day. The visitor hash combines IP address and
# user agent with that day's salt (see VisitorSalt), so the same person counts
# once a day and can't be followed from one day to the next.
class PageView < ApplicationRecord
  Day = Data.define(:day, :visits, :views)

  BOT_USER_AGENT = /
    bot|crawl|spider|slurp|scrap|archiv|fetch|preview|monitor|uptime|lighthouse|headless|
    curl|wget|httpie|python|ruby|perl|go-http|java\/|okhttp|axios|node|
    facebookexternalhit|whatsapp|mastodon|cardyb|chatgpt|perplexity|claude|googleother|-ai\b
  /xi

  def self.record(path:, referrer:, host:, ip:, user_agent:)
    day = Date.current

    create!(
      path: path,
      referrer_host: external_host(referrer, host),
      visitor_hash: OpenSSL::HMAC.hexdigest("SHA256", VisitorSalt.for(day), "#{ip}|#{user_agent}"),
      visited_on: day
    )
  end

  def self.bot?(user_agent)
    user_agent.blank? || user_agent.match?(BOT_USER_AGENT)
  end

  # Only keep where people came from, not clicks between pages on this site
  def self.external_host(referrer, own_host)
    host = URI.parse(referrer.to_s).host&.downcase&.delete_prefix("www.")
    host unless host.blank? || host == own_host.to_s.downcase.delete_prefix("www.")
  rescue URI::InvalidURIError
    nil
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
