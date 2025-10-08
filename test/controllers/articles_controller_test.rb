require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  test "should get blog index" do
    get blog_path
    assert_response :success
    assert_select "h1", "Blog"
  end

  test "should display published articles on index" do
    published = Article.create!(title: "My Published Article", body: "Content", published_at: 1.day.ago)
    draft = Article.create!(title: "My Draft Article", body: "Content", published_at: nil)

    get blog_path
    assert_response :success
    assert_select "h2 a", text: "My Published Article"
    assert_select "h2 a", text: "My Draft Article", count: 0
  end

  test "should filter articles by tag" do
    tag = Tag.create!(name: "ruby")
    article1 = Article.create!(title: "Ruby Article", body: "Content", published_at: 1.day.ago)
    article1.tags << tag

    article2 = Article.create!(title: "Other Article", body: "Content", published_at: 1.day.ago)

    get blog_path(tag: "ruby")
    assert_response :success
    assert_select "h2 a", text: "Ruby Article"
    assert_select "h2 a", text: "Other Article", count: 0
    assert_select "h1", text: /tagged with "ruby"/
  end

  test "should show article by slug" do
    article = Article.create!(title: "Test Article", body: "Test content", published_at: 1.day.ago)

    get article_path(article.slug)
    assert_response :success
    assert_select "h1", "Test Article"
  end

  test "should not show unpublished article" do
    article = Article.create!(title: "Unpublished Draft Post", body: "Content", published_at: nil)

    get article_path(article.slug)
    assert_response :not_found
  end

  test "should display article tags" do
    article = Article.create!(title: "Tagged Article", body: "Content", published_at: 1.day.ago)
    article.tag_list = "ruby, rails"
    article.save!

    get article_path(article.slug)
    assert_response :success
    assert_select ".badge", text: "ruby"
    assert_select ".badge", text: "rails"
  end

  test "should generate RSS feed" do
    get blog_feed_path(format: :rss)
    assert_response :success
    assert_equal "application/rss+xml", @response.media_type
  end

  test "RSS feed should include published articles" do
    published = Article.create!(title: "Published Article", body: "Content for RSS", published_at: 1.day.ago)
    draft = Article.create!(title: "Draft Article", body: "Content", published_at: nil)

    get blog_feed_path(format: :rss)
    assert_response :success

    assert_match "Published Article", @response.body
    assert_no_match "Draft Article", @response.body
  end

  test "RSS feed should limit to 20 articles" do
    25.times do |i|
      Article.create!(title: "Article #{i}", body: "Content #{i}", published_at: i.days.ago)
    end

    get blog_feed_path(format: :rss)
    assert_response :success

    # RSS feed should only include 20 articles
    Article.published.limit(20).each do |article|
      assert_match article.title, @response.body
    end
  end

  test "RSS feed should include article metadata" do
    tag = Tag.create!(name: "testing")
    article = Article.create!(
      title: "Test RSS Article",
      body: "This is RSS test content",
      published_at: 1.day.ago
    )
    article.tags << tag

    get blog_feed_path(format: :rss)
    assert_response :success

    # Check for RSS structure
    assert_match "<title>Test RSS Article</title>", @response.body
    assert_match "<category>testing</category>", @response.body
    assert_match "<author>Simão Belchior</author>", @response.body
    assert_match article_url(article.slug), @response.body
  end
end
