require "test_helper"

class VisitStatsTest < ActiveSupport::TestCase
  SITE = "simaobelchior.com"
  GAMES = PageView::GAMES_HOST

  # Saturday 14 November 2026, mid-afternoon in Lisbon
  NOW = Time.zone.local(2026, 11, 14, 15, 30)

  def view(path: "/", host: SITE, ip: "203.0.113.1", referrer: nil)
    PageView.record(path: path, referrer: referrer, host: host, ip: ip, user_agent: "Chrome")
  end

  def stats(**filters)
    VisitStats.new(**filters)
  end

  test "falls back to the last 30 days on everything for a period or site it doesn't know" do
    travel_to NOW do
      visit_stats = stats(period: "forever", site: "elsewhere")

      assert_equal "30d", visit_stats.period
      assert_equal "all", visit_stats.site
      assert_equal Date.new(2026, 10, 16)..Date.new(2026, 11, 14), visit_stats.days
      assert_equal({}, visit_stats.to_params)
    end
  end

  test "keeps only the filters that aren't defaults in its params" do
    assert_equal({ period: "7d", page: "/about" }, stats(period: "7d", site: "all", page: "/about", from: "").to_params)
  end

  test "counts visits as people per day and sets them against the period before" do
    travel_to NOW - 7.days do
      view(ip: "203.0.113.1")
    end
    travel_to NOW - 2.days do
      view(ip: "203.0.113.1", path: "/")
      view(ip: "203.0.113.1", path: "/about")
      view(ip: "203.0.113.2")
    end
    travel_to NOW do
      view(ip: "203.0.113.1")
      view(ip: "203.0.113.1", host: GAMES, path: "/palminho/")

      visit_stats = stats(period: "7d")
      assert_equal 3, visit_stats.totals.visits
      assert_equal 5, visit_stats.totals.views
      assert_in_delta 5 / 3.0, visit_stats.totals.views_per_visit
      assert_equal VisitStats::Totals.new(visits: 1, views: 1), visit_stats.previous_totals

      assert_equal 1, stats(period: "7d", site: "games").totals.visits
      assert_equal 4, stats(period: "7d", site: "site").totals.views
      assert_nil stats(period: "all").previous_totals
    end
  end

  test "sets today against yesterday up to the same time" do
    travel_to NOW - 1.day - 2.hours do
      view(ip: "203.0.113.1")
    end
    travel_to NOW - 1.day + 2.hours do
      view(ip: "203.0.113.2")
    end
    travel_to NOW do
      assert_equal 1, stats(period: "today").previous_totals.visits
    end
  end

  test "shows today by the hour, each visit in the hour it started" do
    travel_to NOW.change(hour: 9) do
      view(ip: "203.0.113.1")
    end
    travel_to NOW do
      view(ip: "203.0.113.1", path: "/about")
      view(ip: "203.0.113.2")

      buckets = stats(period: "today").buckets
      assert_equal 24, buckets.size
      assert_equal :hour, stats(period: "today").unit
      assert_equal [ 1, 1 ], buckets.values_at(9, 15).map(&:visits)
      assert_equal [ 1, 2 ], buckets.values_at(9, 15).map(&:views)
      assert_equal 2, buckets.sum(&:visits)
    end
  end

  test "shows days up to 90 days, then weeks, then months" do
    travel_to NOW - 3.years do
      view
    end
    travel_to NOW do
      view

      assert_equal [ :day, 7 ], [ stats(period: "7d").unit, stats(period: "7d").buckets.size ]
      assert_equal [ :day, 90 ], [ stats(period: "90d").unit, stats(period: "90d").buckets.size ]

      year = stats(period: "12m")
      assert_equal :week, year.unit
      assert_equal 52, year.buckets.size
      assert year.buckets.all? { |bucket| bucket.starts.monday? }
      assert_equal 1, year.buckets.last.visits

      all_time = stats(period: "all")
      assert_equal :month, all_time.unit
      assert_equal Date.new(2023, 11, 1), all_time.buckets.first.starts
      assert_equal [ 1, 1 ], [ all_time.buckets.first.visits, all_time.buckets.last.visits ]
      assert_equal 2, all_time.buckets.sum(&:visits)
    end
  end

  test "lists the top pages with article titles, keeping the games' pages apart" do
    article = Article.create!(title: "Why I write", body: "Content", published_at: 1.month.ago)

    travel_to NOW do
      view(path: "/blog/#{article.slug}", ip: "203.0.113.1")
      view(path: "/blog/#{article.slug}", ip: "203.0.113.2")
      view(path: "/blog/#{article.slug}", ip: "203.0.113.2")
      view(path: "/")
      view(path: "/", host: GAMES)

      top, *rest = stats.pages
      assert_equal [ SITE, "/blog/#{article.slug}", "Why I write", 2, 3 ], [ top.host, top.path, top.title, top.visits, top.views ]
      assert_equal [ [ GAMES, "/" ], [ SITE, "/" ] ], rest.map { |page| [ page.host, page.path ] }.sort
      assert_equal [ true ], rest.select(&:games?).map(&:games?)
      assert_equal 2, stats.pages(limit: 2).size
    end
  end

  test "lists where visits came from, and how many came direct" do
    travel_to NOW do
      view(ip: "203.0.113.1", referrer: "https://news.ycombinator.com/item?id=1")
      view(ip: "203.0.113.1", path: "/about")
      view(ip: "203.0.113.2", referrer: "https://news.ycombinator.com/")
      view(ip: "203.0.113.3", referrer: "https://www.linkedin.com/")
      view(ip: "203.0.113.4")

      visit_stats = stats
      assert_equal [ [ "news.ycombinator.com", 2 ], [ "linkedin.com", 1 ] ], visit_stats.referrers.map { |referrer| [ referrer.host, referrer.visits ] }
      assert_equal 1, visit_stats.direct_visits
    end
  end

  test "a page filter picks out the visits that included it" do
    article = Article.create!(title: "Why I write", body: "Content", published_at: 1.month.ago)

    travel_to NOW do
      view(ip: "203.0.113.1", path: "/blog/#{article.slug}", referrer: "https://news.ycombinator.com/")
      view(ip: "203.0.113.1", path: "/about")
      view(ip: "203.0.113.2", path: "/about", referrer: "https://github.com/")

      visit_stats = stats(site: "site", page: "/blog/#{article.slug}")
      assert visit_stats.filtered?
      assert_equal "Why I write", visit_stats.page_title
      assert_equal VisitStats::Totals.new(visits: 1, views: 2), visit_stats.totals
      assert_equal [ "/about", "/blog/#{article.slug}" ].sort, visit_stats.pages.map(&:path).sort
      assert_equal [ "news.ycombinator.com" ], visit_stats.referrers.map(&:host)
      assert_nil stats(page: "/about").page_title
    end
  end

  test "a referrer filter picks out the visits that came from it, and every page they read" do
    travel_to NOW do
      view(ip: "203.0.113.1", path: "/", referrer: "https://news.ycombinator.com/")
      view(ip: "203.0.113.1", path: "/about")
      view(ip: "203.0.113.2", path: "/blog", referrer: "https://github.com/")

      visit_stats = stats(from: "news.ycombinator.com")
      assert_equal VisitStats::Totals.new(visits: 1, views: 2), visit_stats.totals
      assert_equal [ "/", "/about" ], visit_stats.pages.map(&:path).sort
      assert_equal 1, visit_stats.buckets.last.visits
    end
  end

  test "lists the most visited articles, leaving out other pages and deleted articles" do
    article = Article.create!(title: "Why I write", body: "Content", published_at: 1.month.ago)

    travel_to NOW do
      view(path: "/blog/#{article.slug}")
      view(path: "/blog/gone", ip: "203.0.113.2")
      view(path: "/blog/gone", ip: "203.0.113.3")
      view(path: "/blog", ip: "203.0.113.4")
      view(path: "/blog/#{article.slug}", host: GAMES, ip: "203.0.113.5")

      assert_equal [ [ "Why I write", 1 ] ], stats.articles.map { |page| [ page.title, page.visits ] }
    end
  end

  test "lists the sites that sent visits for the first time in the period, and where they landed" do
    travel_to NOW - 10.days do
      view(referrer: "https://github.com/")
    end
    travel_to NOW do
      view(ip: "203.0.113.1", referrer: "https://github.com/")
      view(ip: "203.0.113.2", path: "/about", referrer: "https://news.ycombinator.com/")
      view(ip: "203.0.113.3", path: "/about", referrer: "https://news.ycombinator.com/")
      view(ip: "203.0.113.4", path: "/", referrer: "https://news.ycombinator.com/")

      week = stats(period: "7d")
      assert_equal [ VisitStats::Referrer.new(host: "news.ycombinator.com", visits: 3) ], week.new_referrers
      assert_equal "/about", week.landing_page("news.ycombinator.com").path
      assert_equal 2, stats(period: "30d").new_referrers.size
    end
  end

  test "works out an average whole day, leaving out today and the days before counting" do
    travel_to NOW do
      view
      assert_nil stats.average_day_visits
    end
    travel_to NOW - 3.days do
      3.times { |i| view(ip: "203.0.113.#{i}") }
    end
    travel_to NOW - 1.day do
      view
    end
    travel_to NOW do
      assert_equal 4 / 3.0, stats.average_day_visits
    end
  end
end
