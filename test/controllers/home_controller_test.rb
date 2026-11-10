require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get root_path
    assert_response :success
    assert_select "h1", "I build products that help people do their work."
    assert_select "#contact a[href=?]", "mailto:mailme@simaobelchior.com", text: "mailme@simaobelchior.com"
    assert_select "img.home-hero__photo[alt]"
    assert_select "a[href*='x.com']", count: 0
    assert_select "meta[name=description][content=?]", "Software engineer from Porto who builds tools that help people do their work. Now AI Lead at Mindera and founder of Kronflow."
  end

  test "links to the admin only when logged in" do
    get root_path
    assert_select ".site-nav a[href=?]", admin_root_path, count: 0

    post login_path, params: { email: "user1@example.com", password: "password" }
    get root_path
    assert_select ".site-nav a[href=?]", admin_root_path, text: "Admin"
  end

  test "home should link to past companies, with Switch pointing at Teya" do
    get root_path
    assert_select ".org-list a[href=?]", "https://mindera.com", text: "Mindera"
    assert_select ".org-list li", text: /Switch\s*now part of Teya/ do
      assert_select "a[href=?]", "https://www.teya.com", text: "Switch"
    end
  end

  test "should link to favicons that exist" do
    get root_path
    %w[/favicon.ico /favicon.svg /apple-touch-icon.png].each do |path|
      assert_select "link[href=?]", path
      assert Rails.public_path.join(path.delete_prefix("/")).exist?, "#{path} is missing"
    end
  end

  test "home should use the plain footer" do
    get root_path
    assert_select ".site-footer--cta", count: 0
  end

  test "both footers say how visits are counted" do
    [ root_path, about_path ].each do |path|
      get path
      assert_select ".site-footer .site-footer__note", "I count visits without cookies and don't store IP addresses."
    end
  end

  test "should get about" do
    get about_path
    assert_response :success
    assert_select "h1", "The longer story."
    assert_select "meta[name=description][content=?]", "Software engineer from Porto who builds tools that help people do their work. Now AI Lead at Mindera and founder of Kronflow."
    assert_select ".chapter", 5
    assert_select ".chapter__lesson", count: 5
    assert_select ".chapter__lesson", text: /\[/, count: 0
    assert_select ".site-nav a[aria-current=page]", text: "About"
  end

  test "about should use the call-to-action footer" do
    get about_path
    assert_select ".site-footer--cta a[href=?]", root_path(anchor: "contact")
  end

  test "links to GitHub Sponsors from the games page and the footer, not the homepage" do
    sponsor_url = "https://github.com/sponsors/simaob?frequency=one-time"

    get root_path
    assert_select "a[href=?]", sponsor_url, count: 0

    get about_path
    assert_select ".site-footer--cta a[href=?]", sponsor_url, text: "Buy me a coffee"

    get games_path
    assert_select ".games-note a[href=?]", sponsor_url, text: "buy me a coffee" do
      assert_select "svg.sponsor-heart[aria-hidden=true]"
    end
  end

  test "should get games" do
    get games_path
    assert_response :success
    assert_select "h1", "Games I've made."
    assert_select "title", /Games/
    assert_select ".topic-card", 2
    assert_select ".topic-card a[href=?]", "https://games.simaobelchior.com/palminho/"
    assert_select ".topic-card a[href=?]", "https://games.simaobelchior.com/behaving-in-public/"
    assert_select ".topic-card a[href=?]", "https://palmoemeio.com.pt/", text: "Colégio Palmo e Meio"
    assert_select ".topic-card", text: /throwback to a Flash urinal game/
    assert_select ".site-nav a[aria-current=page]", text: "Games"
  end

  test "games should use the call-to-action footer" do
    get games_path
    assert_select ".site-footer--cta a[href=?]", root_path(anchor: "contact")
  end
end
