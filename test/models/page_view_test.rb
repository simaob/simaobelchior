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

  test "counts visits to each page over all time, one per person per day" do
    travel_to Time.zone.local(2026, 11, 9, 12) do
      record(path: "/blog/first")
      record(path: "/blog/first")
      record(path: "/blog/first", ip: "203.0.113.8")
      record(path: "/blog/second")
      record(path: "/about")

      travel 1.day
      record(path: "/blog/first")

      assert_equal({ "/blog/first" => 3, "/blog/second" => 1 }, PageView.visits_by_path([ "/blog/first", "/blog/second", "/blog/none" ]))
    end
  end
end
