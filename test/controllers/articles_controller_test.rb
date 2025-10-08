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
end
