require "test_helper"

class FeedFetchTest < ActiveSupport::TestCase
  FEEDLY = "Feedly/1.0 (+http://www.feedly.com/fetcher.html; %d subscribers; like FeedFetcher-Google)"
  INOREADER = "Mozilla/5.0 (compatible; Inoreader/1.0; +http://www.inoreader.com/feed-fetcher; %d subscribers; )"
  NETNEWSWIRE = "NetNewsWire (RSS Reader; https://netnewswire.com/)"
  CHROME = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"

  def fetch(user_agent, ip: "203.0.113.1")
    FeedFetch.record(ip: ip, user_agent: user_agent)
  end

  test "knows hosted readers by the subscribers they report, and apps by name" do
    assert_equal FeedFetch::Reader.new(name: "Feedly", subscribers: 37), FeedFetch.reader(format(FEEDLY, 37))
    assert_equal FeedFetch::Reader.new(name: "Inoreader", subscribers: 1), FeedFetch.reader(format(INOREADER, 1).sub("subscribers", "subscriber"))
    assert_equal FeedFetch::Reader.new(name: "NewsBlur", subscribers: 5), FeedFetch.reader("NewsBlur Feed Fetcher - 5 subscribers - https://www.newsblur.com/site/1/simao (Mozilla/5.0)")
    assert_equal FeedFetch::Reader.new(name: "Feedspot", subscribers: 3), FeedFetch.reader("Mozilla/5.0 (compatible; Feedspot/1.0; 3 subscribers)")
    assert_equal FeedFetch::Reader.new(name: "NetNewsWire", subscribers: nil), FeedFetch.reader(NETNEWSWIRE)
    assert_equal FeedFetch::Reader.new(name: "Reeder", subscribers: nil), FeedFetch.reader("Reeder/5050.01.00 CFNetwork/1568.100.1 Darwin/24.0.0")
    assert_equal FeedFetch::Reader.new(name: "Other", subscribers: nil), FeedFetch.reader("SomeNewReader/2.1")
  end

  test "doesn't count browsers, crawlers or tools as readers" do
    assert_nil FeedFetch.reader(nil)
    assert_nil FeedFetch.reader(CHROME)
    assert_nil FeedFetch.reader("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")
    assert_nil FeedFetch.reader("curl/8.7.1")
    assert_nil FeedFetch.reader("python-requests/2.32.3")
  end

  test "keeps one row per reader per day, with the last count a hosted reader gave" do
    travel_to Time.zone.local(2026, 11, 14, 9) do
      fetch(format(FEEDLY, 37), ip: "198.51.100.1")
      fetch(format(FEEDLY, 38), ip: "198.51.100.2")
      fetch(NETNEWSWIRE)
      fetch(NETNEWSWIRE)
      fetch(NETNEWSWIRE, ip: "203.0.113.2")
      fetch(CHROME)

      assert_equal 3, FeedFetch.count
      feedly = FeedFetch.find_by!(reader: "Feedly")
      assert_equal [ 38, 2 ], [ feedly.subscribers, feedly.fetches ]
      assert_equal 40, FeedFetch.subscribers_on(Date.current)
      assert_equal({ "Feedly" => 38, "NetNewsWire" => 2 }, FeedFetch.readers_on(Date.current))

      travel 1.day
      fetch(format(FEEDLY, 39))
      assert_equal({ Date.new(2026, 11, 14) => 40, Date.new(2026, 11, 15) => 39 }, FeedFetch.subscribers_by_day(Date.new(2026, 11, 14)..Date.new(2026, 11, 15)))
    end
  end

  test "keeps only the reader's name, not the user agent or IP address" do
    fetch(NETNEWSWIRE, ip: "203.0.113.7")

    row = FeedFetch.sole
    assert_equal "NetNewsWire", row.reader
    assert_match(/\A\h{64}\z/, row.fetcher_hash)
    assert_not_includes FeedFetch.column_names, "user_agent"
    assert_not_includes FeedFetch.column_names, "ip"
  end

  test "gives subscribers for yesterday, unless counting only started today" do
    travel_to Time.zone.local(2026, 11, 14, 9) do
      assert_nil FeedFetch.last_whole_day

      fetch(NETNEWSWIRE)
      assert_equal Date.current, FeedFetch.last_whole_day

      travel 1.day
      assert_equal Date.yesterday, FeedFetch.last_whole_day
    end
  end
end
