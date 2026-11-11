require "test_helper"

class PageViewCountingTest < ActionDispatch::IntegrationTest
  BROWSER = { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36" }

  test "counts a visit to a public page" do
    assert_difference -> { PageView.count } do
      get about_path, headers: BROWSER.merge("Referer" => "https://www.linkedin.com/feed/")
    end

    view = PageView.last
    assert_equal "/about", view.path
    assert_equal "linkedin.com", view.referrer_host
  end

  test "counts blog pages without the query string" do
    article = Article.create!(title: "Counting visits", body: "Content", published_at: 1.day.ago)

    get blog_path(page: 1), headers: BROWSER
    get article_path(article.slug), headers: BROWSER

    assert_equal [ "/blog", "/blog/#{article.slug}" ], PageView.order(:id).pluck(:path)
  end

  test "counts the blogroll page but not its OPML download" do
    get blogroll_path, headers: BROWSER
    get blogroll_path(format: :opml), headers: BROWSER

    assert_equal [ "/blogroll" ], PageView.pluck(:path)
  end

  test "doesn't count bots, prefetches, HEAD requests or the RSS feed" do
    assert_no_difference -> { PageView.count } do
      get root_path, headers: { "User-Agent" => "Mozilla/5.0 (compatible; Googlebot/2.1)" }
      get root_path
      get root_path, headers: BROWSER.merge("X-Sec-Purpose" => "prefetch")
      get root_path, headers: BROWSER.merge("Sec-Purpose" => "prefetch;prerender")
      head root_path, headers: BROWSER
      get blog_feed_path, headers: BROWSER
    end
  end

  test "doesn't count missing pages" do
    assert_no_difference -> { PageView.count } do
      get article_path("no-such-article"), headers: BROWSER
    end
  end

  test "doesn't count visits while logged in" do
    post login_path, params: { email: "user1@example.com", password: "password" }

    assert_no_difference -> { PageView.count } do
      get root_path, headers: BROWSER
      get admin_root_path, headers: BROWSER
    end
  end

  test "doesn't load Google Analytics or prefetch links on hover" do
    get root_path, headers: BROWSER
    assert_select "script[src*='googletagmanager']", count: 0
    assert_select "meta[name='turbo-prefetch'][content='false']"
  end
end
