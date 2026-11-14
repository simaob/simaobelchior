require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  def log_in
    post login_path, params: { email: "user1@example.com", password: "password" }
  end

  def view(path: "/about", host: "www.example.com", ip: "203.0.113.1", referrer: nil)
    PageView.record(path: path, referrer: referrer, host: host, ip: ip, user_agent: "Chrome")
  end

  test "should redirect to login when not authenticated" do
    get admin_root_url
    assert_redirected_to login_path
  end

  test "shows today's visits on the website and the games, against an average day" do
    travel_to 2.days.ago do
      4.times { |i| view(ip: "203.0.113.#{i}") }
    end
    3.times { |i| view(ip: "203.0.113.#{i}") }
    2.times { |i| view(path: "/palminho/", host: PageView::GAMES_HOST, ip: "203.0.113.#{i + 5}") }
    log_in

    get admin_root_url
    assert_response :success
    assert_select "#today .dashboard-today__total strong", "5"
    assert_select "#today p", "About 2 on an average day in the last 30 days"
    assert_select "#today a[href=?]", admin_visits_path(period: "today", site: "site"), "3 on the website"
    assert_select "#today a[href=?]", admin_visits_path(period: "today", site: "games"), "2 on the games"
    assert_select "#today .visits-chart--small .visits-chart__day", 30
    assert_select "#today a[href=?]", admin_visits_path
  end

  test "shows the articles read this week" do
    read = Article.create!(title: "Read most", body: "Content", published_at: 1.month.ago)
    also = Article.create!(title: "Read less", body: "Content", published_at: 1.month.ago)
    2.times { |i| view(path: "/blog/#{read.slug}", ip: "203.0.113.#{i}") }
    view(path: "/blog/#{also.slug}")
    view(path: "/blog/deleted-article")
    log_in

    get admin_root_url
    assert_equal [ "Read most", "Read less" ], css_select("#popular .dash-list__title").map(&:text)
    assert_select "#popular a[href=?]", admin_visits_path(period: "7d", site: "site", page: "/blog/#{read.slug}")
    assert_select "#popular .dash-list__count", "2 visits"
  end

  test "shows sites linking here for the first time this week, and what they linked to" do
    article = Article.create!(title: "Why I write", body: "Content", published_at: 1.month.ago)
    travel_to 10.days.ago do
      view(referrer: "https://github.com/")
    end
    view(referrer: "https://github.com/")
    view(path: "/blog/#{article.slug}", ip: "203.0.113.2", referrer: "https://news.ycombinator.com/item?id=1")
    log_in

    get admin_root_url
    assert_select "#new-referrers .dash-list__title", count: 1
    assert_select "#new-referrers a[href=?]", admin_visits_path(period: "7d", from: "news.ycombinator.com"), "news.ycombinator.com"
    assert_select "#new-referrers .dash-list__meta", "to Why I write"
  end

  test "shows recently published articles with their visits, and the drafts in progress" do
    published = Article.create!(title: "Out there", body: "Content", published_at: 3.days.ago)
    Article.create!(title: "Half written", body: "One two three")
    Article.create!(title: "Coming soon", body: "Content", published_at: 2.days.from_now)
    3.times { |i| view(path: "/blog/#{published.slug}", ip: "203.0.113.#{i}") }
    log_in

    get admin_root_url
    assert_select "#recently-published p", "The last one 3 days ago"
    assert_select "#recently-published li", text: /Out there/ do
      assert_select ".article-visits", "3 visits"
    end
    assert_select "#drafts li", text: /Half written/ do
      assert_select ".dash-list__meta", /3 words · edited less than a minute ago/
    end
    assert_select "#drafts li", text: /Coming soon/ do
      assert_select ".dash-list__meta", /out on #{2.days.from_now.strftime("%-d %B")}/
    end
    assert_select "p", /3 articles, 1 published and 2 in progress/
  end

  test "shows an empty dashboard" do
    log_in

    get admin_root_url
    assert_response :success
    assert_select "#today .dashboard-today__total strong", "0"
    assert_select "#today p", text: /average day/, count: 0
    assert_select "#new-referrers p", "No new sites this week."
    assert_select "#popular p", "No article has been read this week."
    assert_select "#recently-published p", "Nothing published yet."
  end
end
