# The numbers on the admin's Visits page for one period, on this site, the games
# or both: totals against the period before, visits over time, and the top pages
# and referrers. A visit is one person on one day, see PageView.
#
# Narrowing to a page or a referrer picks out the visits that included that page,
# or that came from that site. Everything else is then about those visits: how
# many pages they read, which ones, and where they came from.
class VisitStats
  PERIODS = {
    "today" => "Today",
    "7d" => "7 days",
    "30d" => "30 days",
    "90d" => "90 days",
    "12m" => "12 months",
    "all" => "All time"
  }.freeze
  SITES = { "all" => "Everything", "site" => "Website", "games" => "Games" }.freeze
  DEFAULTS = { period: "30d", site: "all" }.freeze

  ARTICLE_PATH = %r{\A/blog/([^/]+)\z}

  Totals = Data.define(:visits, :views) do
    def views_per_visit
      visits.zero? ? 0 : views.fdiv(visits)
    end
  end

  # One bar on the chart. Unit is :hour, :day, :week or :month, starting at starts
  Bucket = Data.define(:starts, :unit, :visits, :views)

  # Title is the article's, for pages that are articles
  Page = Data.define(:host, :path, :title, :visits, :views) do
    def games?
      host == PageView::GAMES_HOST
    end
  end

  Referrer = Data.define(:host, :visits)

  attr_reader :period, :site, :page, :from

  def initialize(period: nil, site: nil, page: nil, from: nil)
    @period = PERIODS.key?(period) ? period : DEFAULTS[:period]
    @site = SITES.key?(site) ? site : DEFAULTS[:site]
    @page = page.presence
    @from = from.presence
  end

  # The filters as URL params, leaving out the defaults
  def to_params
    { period: period, site: site, page: page, from: from }.reject { |key, value| value.nil? || DEFAULTS[key] == value }
  end

  def filtered?
    page.present? || from.present?
  end

  # The title of the article the page filter is on, if it's one
  def page_title
    slug = page&.slice(ARTICLE_PATH, 1)
    Article.find_by(slug: slug)&.title if slug && site != "games"
  end

  def days
    @days ||= case period
    when "today" then today..today
    when "7d" then (today - 6)..today
    when "30d" then (today - 29)..today
    when "90d" then (today - 89)..today
    when "12m" then (today.prev_year + 1)..today
    else (on_site.minimum(:visited_on) || today)..today
    end
  end

  def unit
    @unit ||= if period == "today" then :hour
    elsif days.count <= 92 then :day
    elsif days.count <= 731 then :week
    else :month
    end
  end

  def totals
    @totals ||= totals_for(views)
  end

  # The same filters over the same number of days just before, up to the same
  # time of day, so a day that has only just started isn't set against a whole one
  def previous_totals
    return if period == "all"

    @previous_totals ||= begin
      length = days.count
      totals_for(views_in((days.begin - length)..(days.begin - 1), before: Time.current - length.days))
    end
  end

  def buckets
    @buckets ||= unit == :hour ? hourly_buckets : daily_buckets
  end

  # Estimated feed subscribers each day, or on an average day of each week or month,
  # up to the last whole day (see FeedFetch). Nil for today, which has no whole day.
  def feed_buckets
    return if unit == :hour

    last_day = FeedFetch.last_whole_day or return []
    by_day = FeedFetch.subscribers_by_day(days.begin..last_day)

    bucket_ranges.filter_map do |starts, in_bucket|
      counted = by_day.values_at(*in_bucket.select { |day| day <= last_day }).compact
      next if starts > last_day

      Bucket.new(starts: starts, unit: unit, visits: counted.empty? ? 0 : counted.sum.fdiv(counted.size).round, views: nil)
    end
  end

  def pages(limit: 10)
    ranked_pages(views, limit)
  end

  # The most visited articles, leaving out the pages of articles since deleted
  def articles(limit: 5)
    article_paths = Article.select(Arel.sql("'/blog/' || slug"))
    ranked_pages(views.where.not(host: PageView::GAMES_HOST).where(path: article_paths), limit)
  end

  # The page the most visits from this site started on
  def landing_page(referrer_host)
    ranked_pages(views.where(referrer_host: referrer_host), 1).first
  end

  def referrers(limit: 10)
    views.where.not(referrer_host: nil)
      .group(:referrer_host)
      .order(Arel.sql("COUNT(DISTINCT visitor_hash) DESC"), :referrer_host)
      .limit(limit)
      .distinct
      .count(:visitor_hash)
      .map { |host, visits| Referrer.new(host: host, visits: visits) }
  end

  # Sites that sent visits in this period and never before it
  def new_referrers(limit: 5)
    seen_before = on_site.where(visited_on: ...days.begin).where.not(referrer_host: nil).select(:referrer_host)
    views.where.not(referrer_host: nil)
      .where.not(referrer_host: seen_before)
      .group(:referrer_host)
      .order(Arel.sql("COUNT(DISTINCT visitor_hash) DESC"), :referrer_host)
      .limit(limit)
      .distinct
      .count(:visitor_hash)
      .map { |host, visits| Referrer.new(host: host, visits: visits) }
  end

  # Visits on an average whole day of this period, leaving out today, which isn't
  # over yet, and the days before counting started. Nil until there's a whole day.
  def average_day_visits
    counting_started = on_site.minimum(:visited_on) or return
    whole_days = [ days.begin, counting_started ].max...today
    return if whole_days.none?

    views.where(visited_on: whole_days).group(:visited_on).distinct.count(:visitor_hash).values.sum.fdiv(whole_days.count)
  end

  # Visits with no other site sending them: typed in, from a bookmark or an app,
  # or from a site that doesn't say
  def direct_visits
    totals.visits - views.where.not(referrer_host: nil).distinct.count(:visitor_hash)
  end

  private

  def today
    Date.current
  end

  def on_site
    case site
    when "site" then PageView.site
    when "games" then PageView.games
    else PageView.all
    end
  end

  def views
    @views ||= views_in(days)
  end

  # Page views in these days from the visits picked out by the filters. Visitor
  # hashes change every day, so a hash picks out one person on one day.
  def views_in(days, before: nil)
    scope = on_site.where(visited_on: days)
    scope = scope.where(created_at: ..before) if before
    scope = scope.where(visitor_hash: scope.where(path: page).select(:visitor_hash)) if page
    scope = scope.where(visitor_hash: scope.where(referrer_host: from).select(:visitor_hash)) if from
    scope
  end

  def ranked_pages(scope, limit)
    rows = scope.group(:host, :path)
      .order(Arel.sql("COUNT(DISTINCT visitor_hash) DESC, COUNT(*) DESC"), :path)
      .limit(limit)
      .pluck(:host, :path, Arel.sql("COUNT(DISTINCT visitor_hash)"), Arel.sql("COUNT(*)"))
    titles = article_titles(rows)

    rows.map do |host, path, visits, page_views|
      Page.new(host: host, path: path, title: titles[[ host, path ]], visits: visits, views: page_views)
    end
  end

  def totals_for(scope)
    Totals.new(visits: scope.distinct.count(:visitor_hash), views: scope.count)
  end

  # Days, weeks or months, each the sum of its days, since a visit only lasts a day
  def daily_buckets
    by_day = views.group(:visited_on)
    visits_by_day = by_day.distinct.count(:visitor_hash)
    views_by_day = by_day.count

    bucket_ranges.map do |starts, in_bucket|
      Bucket.new(
        starts: starts,
        unit: unit,
        visits: in_bucket.sum { |day| visits_by_day.fetch(day, 0) },
        views: in_bucket.sum { |day| views_by_day.fetch(day, 0) }
      )
    end
  end

  # The day, week or month each bar starts on, and the days of the period in it
  def bucket_ranges
    step = { day: 1.day, week: 1.week, month: 1.month }.fetch(unit)

    bucket_starts(step).map do |starts|
      [ starts, [ starts, days.begin ].max..[ starts + step - 1.day, days.end ].min ]
    end
  end

  def bucket_starts(step)
    first = case unit
    when :week then days.begin.beginning_of_week
    when :month then days.begin.beginning_of_month
    else days.begin
    end

    starts = [ first ]
    starts << starts.last + step while starts.last + step <= days.end
    starts
  end

  # Today by the hour. Each visit counts in the hour it started, so the hours add
  # up to the day's visits.
  def hourly_buckets
    rows = views.pluck(:visitor_hash, :created_at)
    arrivals = rows.group_by(&:first).values.map { |visit| visit.map(&:last).min.hour }.tally
    views_by_hour = rows.map { |_, created_at| created_at.hour }.tally

    (0..23).map do |hour|
      Bucket.new(starts: today.in_time_zone.change(hour: hour), unit: :hour, visits: arrivals.fetch(hour, 0), views: views_by_hour.fetch(hour, 0))
    end
  end

  def article_titles(rows)
    slugs = rows.filter_map do |host, path, *|
      path[ARTICLE_PATH, 1] unless host == PageView::GAMES_HOST
    end
    titles = Article.where(slug: slugs).pluck(:slug, :title).to_h

    rows.each_with_object({}) do |(host, path, *), found|
      title = titles[path[ARTICLE_PATH, 1]] unless host == PageView::GAMES_HOST
      found[[ host, path ]] = title if title
    end
  end
end
