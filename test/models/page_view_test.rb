require "test_helper"

class PageViewTest < ActiveSupport::TestCase
  CHROME = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"

  def record(ip: "203.0.113.7", user_agent: CHROME, path: "/", referrer: nil)
    PageView.record(path: path, referrer: referrer, host: "simaobelchior.com", ip: ip, user_agent: user_agent)
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
