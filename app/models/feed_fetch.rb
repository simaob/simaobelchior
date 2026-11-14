# Feed readers fetching the blog's RSS feed, counted to estimate how many people
# subscribe. Readers fetch the feed every so often whether anyone reads it or not,
# so counting fetches would mostly count polling. Instead there's one row per reader
# per day, however often it fetches:
#
# - Hosted readers like Feedly or Inoreader fetch once for everyone subscribed
#   through them, and say how many that is in their user agent. Their row keeps the
#   last number they gave that day.
# - Apps on people's own devices, like NetNewsWire, fetch for one person each. Their
#   row counts as one, told apart from others that day by a hash of the IP address
#   and user agent with the day's salt, like a page view's visitor hash.
#
# Only the reader's name is kept, not the user agent or the IP address. Browsers
# opening the feed and crawlers aren't counted.
class FeedFetch < ApplicationRecord
  # Readers on people's own devices, or self-hosted for one person
  APPS = {
    "NetNewsWire" => /netnewswire/i,
    "Reeder" => /reeder/i,
    "ReadKit" => /readkit/i,
    "Unread" => /\bunread\b/i,
    "Fiery Feeds" => /fiery ?feeds/i,
    "lire" => /\blire\b/i,
    "Vienna" => /\bvienna\b/i,
    "Thunderbird" => /thunderbird/i,
    "Feeder" => /\bfeeder\b/i,
    "Feedbro" => /feedbro/i,
    "NewsFlash" => /newsflash/i,
    "Akregator" => /akregator/i,
    "Liferea" => /liferea/i,
    "Newsboat" => /newsboat/i,
    "Miniflux" => /miniflux/i,
    "FreshRSS" => /freshrss/i,
    "Tiny Tiny RSS" => /tiny tiny rss|tt-rss/i
  }.freeze

  # Hosted readers, which usually say how many subscribe through them
  HOSTED = {
    "Feedly" => /feedly/i,
    "Inoreader" => /inoreader/i,
    "NewsBlur" => /newsblur/i,
    "Feedbin" => /feedbin/i,
    "The Old Reader" => /theoldreader/i,
    "Feedspot" => /feedspot/i,
    "BazQux" => /bazqux/i,
    "Readwise" => /readwise/i
  }.freeze

  SUBSCRIBERS = /(\d+) subscribers?/i

  # A browser opening the feed: someone looking at it, not subscribing to it
  BROWSER = %r{\AMozilla/5\.0 \((?!compatible)[^)]*\).*\b(?:Chrome|Firefox|Safari)/}

  # Subscribers on day, the same a week before when counting had started, and by reader
  Summary = Data.define(:day, :subscribers, :week_before, :readers)

  Reader = Data.define(:name, :subscribers) do
    def hosted?
      !subscribers.nil?
    end
  end

  # The reader behind a user agent, or nil when it isn't one
  def self.reader(user_agent)
    return if user_agent.blank?

    subscribers = user_agent[SUBSCRIBERS, 1]&.to_i
    name = HOSTED.find { |_, pattern| user_agent.match?(pattern) }&.first ||
      APPS.find { |_, pattern| user_agent.match?(pattern) }&.first

    if subscribers
      Reader.new(name: name || product_name(user_agent), subscribers: subscribers)
    elsif name
      Reader.new(name: name, subscribers: nil)
    elsif !user_agent.match?(BROWSER) && !PageView.bot?(user_agent)
      Reader.new(name: "Other", subscribers: nil)
    end
  end

  # The first product in a user agent that isn't a browser engine, like "Feedspot" in
  # "Mozilla/5.0 (compatible; Feedspot/1.0; 3 subscribers)"
  def self.product_name(user_agent)
    user_agent.scan(%r{([A-Za-z][\w.-]*)/\d}).flatten.find { |name| !name.match?(/\A(Mozilla|AppleWebKit|Safari|Chrome|Gecko|KHTML)\z/i) } || "Other"
  end

  def self.record(ip:, user_agent:)
    found = reader(user_agent) or return
    day = Date.current

    upsert(
      {
        fetched_on: day,
        fetcher_hash: fetcher_hash(found, day: day, ip: ip, user_agent: user_agent),
        reader: found.name,
        subscribers: found.subscribers,
        fetches: 1
      },
      unique_by: [ :fetched_on, :fetcher_hash ],
      on_duplicate: Arel.sql("fetches = fetches + 1, subscribers = excluded.subscribers, updated_at = excluded.updated_at")
    )
  end

  # A hosted reader is the same one all day whatever IP it fetches from, and its user
  # agent changes with its count, so it goes by its user agent without the count.
  # Readers that put a feed id in their user agent then count once per feed, which
  # matters if people subscribe to the feed at more than one address.
  def self.fetcher_hash(reader, day:, ip:, user_agent:)
    if reader.hosted?
      Digest::SHA256.hexdigest("#{reader.name}|#{user_agent.gsub(SUBSCRIBERS, "")}")
    else
      OpenSSL::HMAC.hexdigest("SHA256", VisitorSalt.for(day), "feed|#{ip}|#{user_agent}")
    end
  end

  # Estimated subscribers on each of these days that has any fetches
  def self.subscribers_by_day(days)
    where(fetched_on: days).group(:fetched_on).sum(Arel.sql("COALESCE(subscribers, 1)"))
  end

  def self.subscribers_on(day)
    where(fetched_on: day).sum(Arel.sql("COALESCE(subscribers, 1)"))
  end

  # Estimated subscribers through each reader on a day, most first
  def self.readers_on(day)
    where(fetched_on: day)
      .group(:reader)
      .order(Arel.sql("SUM(COALESCE(subscribers, 1)) DESC"), :reader)
      .sum(Arel.sql("COALESCE(subscribers, 1)"))
  end

  # The day to give subscribers for: yesterday, since apps fetch at all hours and
  # today isn't over, unless counting only started today. Nil before any fetch.
  def self.last_whole_day
    started = minimum(:fetched_on) or return
    started < Date.current ? Date.yesterday : Date.current
  end

  # Subscribers on the last whole day, or nil before any fetch
  def self.summary
    day = last_whole_day or return
    readers = readers_on(day)
    week_before = subscribers_on(day - 7) if minimum(:fetched_on) <= day - 7

    Summary.new(day: day, subscribers: readers.values.sum, week_before: week_before, readers: readers)
  end
end
