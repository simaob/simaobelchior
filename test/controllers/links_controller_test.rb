require "test_helper"

class LinksControllerTest < ActionDispatch::IntegrationTest
  test "lists the blogroll by name, with a line on each site" do
    get blogroll_path
    assert_response :success
    assert_select "title", /\ABlogroll/
    assert_select "h1", "Sites I read."
    assert_equal [ "Ana's Notes", "bea writes", "Zed" ], css_select(".link-list__name a").map(&:text)

    assert_select ".link-list__item", text: /Ana's Notes/ do
      assert_select "h2 a[href=?]", "https://www.ana.example/"
      assert_select ".link-list__meta", /ana\.example/
      assert_select ".link-list__feed[href=?]", "https://www.ana.example/feed.xml", text: "RSS"
      assert_select ".link-list__text", "Short posts about running small teams."
    end
    assert_select ".link-list__item", text: /Zed/ do
      assert_select ".link-list__feed", count: 0
      assert_select ".link-list__text", count: 0
    end
  end

  test "offers the feeds as OPML" do
    get blogroll_path
    assert_select "a[href=?]", blogroll_path(format: :opml), text: /Download as OPML/
    assert_select "link[rel=blogroll][href=?]", blogroll_path(format: :opml)
  end

  test "uses the call-to-action footer, which links back to the blogroll" do
    get blogroll_path
    assert_select ".site-footer--cta a[href=?]", root_path(anchor: "contact")
    assert_select ".site-footer__links a[href=?]", blogroll_path, text: "Blogroll"
  end

  test "downloads every site with a feed as OPML" do
    get blogroll_path(format: :opml)
    assert_response :success
    assert_equal "text/x-opml", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]

    opml = Nokogiri::XML(response.body)
    assert_equal "Simão Belchior's blogroll", opml.at_xpath("/opml/head/title").text
    outlines = opml.xpath("/opml/body/outline")
    assert_equal [ "Ana's Notes", "bea writes" ], outlines.map { |outline| outline["text"] }
    assert_equal "rss", outlines.first["type"]
    assert_equal "https://www.ana.example/feed.xml", outlines.first["xmlUrl"]
    assert_equal "https://www.ana.example/", outlines.first["htmlUrl"]
  end

  test "has nothing to offer when empty" do
    Link.delete_all

    get blogroll_path
    assert_response :success
    assert_select ".empty-state", "Nothing here yet."
    assert_select "a[href=?]", blogroll_path(format: :opml), count: 0
    assert_select "link[rel=blogroll]", count: 0
  end

  test "doesn't take other formats" do
    get "/blogroll.json"
    assert_response :not_found
  end
end
