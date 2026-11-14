require "test_helper"

class Admin::VisitsControllerTest < ActionDispatch::IntegrationTest
  def log_in
    post login_path, params: { email: "user1@example.com", password: "password" }
  end

  def view(path: "/about", host: "www.example.com", ip: "203.0.113.1", referrer: nil)
    PageView.record(path: path, referrer: referrer, host: host, ip: ip, user_agent: "Chrome")
  end

  test "should redirect to login when not authenticated" do
    get admin_visits_path
    assert_redirected_to login_path
  end

  test "shows the site's and the games' visits together for the last 30 days" do
    3.times { |i| view(ip: "203.0.113.#{i}", referrer: "https://github.com/") }
    2.times { |i| view(path: "/palminho/", host: PageView::GAMES_HOST, ip: "203.0.113.#{i + 5}", referrer: "https://simaobelchior.com/") }
    log_in

    get admin_visits_path
    assert_response :success
    assert_select "title", /\AVisits/
    assert_select "h1", "Visits"
    assert_select "nav[aria-label=Period] a[aria-current]", "30 days"
    assert_select "nav[aria-label=Site] a[aria-current]", "Everything"
    assert_select ".visits-total", "5"
    assert_select "h2", "Visits per day"
    assert_select ".visits-chart__day", 30
    assert_select ".visits-chart__day:last-child[aria-label$=?]", "5 visits, 5 page views"

    assert_select "#visits-pages td a.visits-rank__link[href=?]", admin_visits_path(site: "site", page: "/about"), "/about"
    assert_select "#visits-pages td a.visits-rank__open[href='/about']"
    assert_select "#visits-pages td .visits-rank__tag", "Games"
    assert_select "#visits-pages td a.visits-rank__open[href=?]", "https://games.simaobelchior.com/palminho/"
    assert_select "#visits-referrers td a.visits-rank__link[href=?]", admin_visits_path(from: "github.com"), "github.com"
    assert_select "#visits-referrers td .visits-rank__link", "simaobelchior.com"
  end

  test "picks a period and a site" do
    view
    view(path: "/palminho/", host: PageView::GAMES_HOST, ip: "203.0.113.9")
    log_in

    get admin_visits_path(period: "today", site: "games")
    assert_select "nav[aria-label=Period] a[aria-current]", "Today"
    assert_select "nav[aria-label=Site] a[aria-current]", "Games"
    assert_select "nav[aria-label=Period] a[href=?]", admin_visits_path(period: "7d", site: "games"), "7 days"
    assert_select "h2", "Visits per hour"
    assert_select ".visits-chart__day", 24
    assert_select ".visits-total", "1"
    assert_select ".visits-change", "Nothing in yesterday by this time"
    assert_select "#visits-pages .visits-rank__link", text: "/about", count: 0
    assert_select "#visits-pages .visits-rank__tag", count: 0

    get admin_visits_path(period: "all")
    assert_select ".visits-change", count: 0
  end

  test "narrows to the visits that included a page, with a way back" do
    article = Article.create!(title: "Why I write", body: "Content", published_at: 1.day.ago)
    view(path: "/blog/#{article.slug}", referrer: "https://news.ycombinator.com/")
    view(path: "/about")
    view(ip: "203.0.113.2", referrer: "https://github.com/")
    log_in

    get admin_visits_path(site: "site", page: "/blog/#{article.slug}")
    assert_select ".visits-filter strong", "Why I write"
    assert_select ".visits-filter a[href=?]", admin_visits_path(site: "site")
    assert_select ".visits-total", "1"
    assert_select "#visits-pages td a.visits-rank__link", "Why I write"
    assert_select "#visits-pages td a.visits-rank__link", "/about"
    assert_select "#visits-referrers .visits-rank__link", "news.ycombinator.com"
    assert_select "#visits-referrers .visits-rank__link", text: "github.com", count: 0
  end

  test "narrows to the visits from one site" do
    view(referrer: "https://news.ycombinator.com/")
    view(ip: "203.0.113.2", path: "/", referrer: "https://github.com/")
    log_in

    get admin_visits_path(from: "news.ycombinator.com")
    assert_select ".visits-filter strong", "news.ycombinator.com"
    assert_select ".visits-total", "1"
    assert_select "#visits-pages .visits-rank__link", text: "/", count: 0
    assert_select ".visits-rank__direct", count: 0
  end

  test "shows the top 10 pages, and all of them when asked" do
    11.times { |i| view(path: "/page-#{i}") }
    log_in

    get admin_visits_path
    assert_select "#visits-pages tbody tr", 10
    assert_select "#visits-pages a[href=?]", admin_visits_path(show: "pages", anchor: "visits-pages"), "Show all pages"

    get admin_visits_path(show: "pages")
    assert_select "#visits-pages tbody tr", 11
    assert_select "#visits-pages a", "Show the top 10"
  end

  test "shows feed subscribers on the website, not the games or a filtered view" do
    travel_to 8.days.ago do
      FeedFetch.record(ip: "198.51.100.1", user_agent: "Feedly/1.0 (30 subscribers)")
    end
    travel_to 1.day.ago do
      FeedFetch.record(ip: "198.51.100.1", user_agent: "Feedly/1.0 (37 subscribers)")
      FeedFetch.record(ip: "203.0.113.1", user_agent: "NetNewsWire (RSS Reader; https://netnewswire.com/)")
    end
    log_in

    get admin_visits_path
    assert_select "#feed .visits-total", "38"
    assert_select "#feed p", "Yesterday"
    assert_select "#feed .visits-change", "8 more than a week before"
    assert_select "#feed h3", "Subscribers each day"
    assert_select "#feed .visits-chart__day", 29
    assert_select "#feed .visits-chart__day:last-child[aria-label$=?]", "38 subscribers"
    assert_select "#feed td", "Feedly"

    get admin_visits_path(period: "today")
    assert_select "#feed .visits-total", "38"
    assert_select "#feed .visits-chart", count: 0

    get admin_visits_path(site: "games")
    assert_select "#feed", count: 0
    get admin_visits_path(from: "github.com")
    assert_select "#feed", count: 0
  end

  test "sends the old game visits page to the games on the Visits page" do
    get "/admin/visits/games"
    assert_redirected_to "/admin/visits?site=games"
  end

  test "shows empty visit stats" do
    log_in

    get admin_visits_path
    assert_response :success
    assert_select ".visits-chart__day", 30
    assert_select "#visits-pages p", "No page views in this period."
    assert_select "#visits-referrers p", "No visits in this period."
  end
end
