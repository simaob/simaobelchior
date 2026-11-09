require "test_helper"

class PageViewTest < ActiveSupport::TestCase
  CHROME = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"

  def record(ip: "203.0.113.7", user_agent: CHROME, path: "/", referrer: nil, host: "simaobelchior.com")
    PageView.record(path: path, referrer: referrer, host: host, ip: ip, user_agent: user_agent)
  end

  test "stores the host without www, and keeps the games apart from this site" do
    site = record(host: "www.simaobelchior.com", path: "/about")
    game = record(host: PageView::GAMES_HOST, path: "/palminho/")

    assert_equal "simaobelchior.com", site.host
    assert_equal [ site ], PageView.site.to_a
    assert_equal [ game ], PageView.games.to_a
  end

  test "a game's referrer from this site is external to the games" do
    assert_equal "simaobelchior.com", record(host: PageView::GAMES_HOST, referrer: "https://simaobelchior.com/").referrer_host
    assert_nil record(host: PageView::GAMES_HOST, referrer: "https://games.simaobelchior.com/behaving-in-public/").referrer_host
  end

  test "summarises one site's visits, pages and referrers" do
    record(path: "/about", referrer: "https://github.com/")
    record(host: PageView::GAMES_HOST, path: "/palminho/", referrer: "https://simaobelchior.com/")

    summary = PageView.games.summary(days: 7)
    assert_equal 7, summary.days.size
    assert_equal 1, summary.days.last.visits
    assert_equal({ "/palminho/" => 1 }, summary.top_pages)
    assert_equal({ "simaobelchior.com" => 1 }, summary.top_referrers)
  end

  test "stores the page and day but not the IP address or user agent" do
    view = record(ip: "203.0.113.7", path: "/about")

    assert_equal "/about", view.path
    assert_equal Date.current, view.visited_on
    assert_match(/\A\h{64}\z/, view.visitor_hash)
    assert_not_includes PageView.column_names, "ip"
    assert_not_includes PageView.column_names, "user_agent"
  end

  test "the same person gets the same hash all day, and a new one the next day" do
    travel_to Time.zone.local(2026, 11, 9, 9) do
      first = record.visitor_hash
      assert_equal first, record.visitor_hash
      assert_not_equal first, record(ip: "203.0.113.8").visitor_hash
      assert_not_equal first, record(user_agent: "#{CHROME} Edg/141.0").visitor_hash

      travel 1.day
      assert_not_equal first, record.visitor_hash
    end
  end

  test "deletes the previous day's salt once a new day starts" do
    travel_to Time.zone.local(2026, 11, 9, 23) do
      record
      travel 2.hours
      record
    end

    assert_equal [ Date.new(2026, 11, 10) ], VisitorSalt.pluck(:day)
  end

  test "keeps external referrers only, without www" do
    assert_equal "news.ycombinator.com", record(referrer: "https://news.ycombinator.com/item?id=1").referrer_host
    assert_equal "linkedin.com", record(referrer: "https://www.linkedin.com/").referrer_host
    assert_nil record(referrer: "https://www.simaobelchior.com/about").referrer_host
    assert_nil record(referrer: "not a url").referrer_host
    assert_nil record(referrer: nil).referrer_host
  end

  test "spots bots and tools" do
    assert PageView.bot?(nil)
    assert PageView.bot?("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")
    assert PageView.bot?("Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; ClaudeBot/1.0)")
    assert PageView.bot?("curl/8.7.1")
    assert PageView.bot?("facebookexternalhit/1.1")
    assert_not PageView.bot?(CHROME)
  end

  test "counts visits and page views per day, with empty days filled in" do
    travel_to Time.zone.local(2026, 11, 9, 12) do
      record(path: "/")
      record(path: "/about")
      record(ip: "203.0.113.8")

      travel 1.day
      record

      days = PageView.by_day(days: 3)
      assert_equal [ Date.new(2026, 11, 8), Date.new(2026, 11, 9), Date.new(2026, 11, 10) ], days.map(&:day)
      assert_equal [ 0, 2, 1 ], days.map(&:visits)
      assert_equal [ 0, 3, 1 ], days.map(&:views)
    end
  end

  test "ranks pages by views and referrers by visits" do
    record(path: "/about")
    record(path: "/about", ip: "203.0.113.8", referrer: "https://www.linkedin.com/")
    record(path: "/", referrer: "https://www.linkedin.com/")
    record(path: "/", ip: "203.0.113.9", referrer: "https://github.com/")

    assert_equal({ "/" => 2, "/about" => 2 }, PageView.top_pages(since: Date.current))
    assert_equal({ "linkedin.com" => 2, "github.com" => 1 }, PageView.top_referrers(since: Date.current))
  end
end
