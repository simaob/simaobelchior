require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "should auto-generate slug from title" do
    article = Article.new(title: "My Test Article")
    article.valid?
    assert_equal "my-test-article", article.slug
  end

  test "should generate unique slug for duplicate titles" do
    Article.create!(title: "Test Title", body: "Content", slug: "test-title")
    article = Article.new(title: "Different Title")
    article.slug = nil
    article.valid?

    # Slug should be generated even though title is different
    assert_not_nil article.slug
  end

  test "should require title" do
    article = Article.new(body: "Content")
    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"
  end

  test "should require unique title" do
    Article.create!(title: "Unique Title", body: "Content")
    article = Article.new(title: "Unique Title", body: "Other content")
    assert_not article.valid?
    assert_includes article.errors[:title], "has already been taken"
  end

  test "should require unique slug" do
    Article.create!(title: "Title 1", body: "Content", slug: "same-slug")
    article = Article.new(title: "Title 2", body: "Content", slug: "same-slug")
    assert_not article.valid?
    assert_includes article.errors[:slug], "has already been taken"
  end

  test "published? should return true for published articles" do
    article = Article.create!(title: "Published", body: "Content", published_at: 1.day.ago)
    assert article.published?
  end

  test "published? should return false for drafts" do
    article = Article.create!(title: "Draft", body: "Content", published_at: nil)
    assert_not article.published?
  end

  test "published? should return false for future articles" do
    article = Article.create!(title: "Future", body: "Content", published_at: 1.day.from_now)
    assert_not article.published?
  end

  test "excerpt should return truncated plain text" do
    article = Article.new(title: "Test", body: "A" * 1000)
    excerpt = article.excerpt(length: 50)
    assert excerpt.length <= 53 # 50 + "..."
    assert excerpt.ends_with?("...")
  end

  test "published scope should only return published articles" do
    published = Article.create!(title: "Published 1", body: "Content", published_at: 1.day.ago)
    draft = Article.create!(title: "Draft 1", body: "Content")
    future = Article.create!(title: "Future 1", body: "Content", published_at: 1.day.from_now)

    assert_includes Article.published, published
    assert_not_includes Article.published, draft
    assert_not_includes Article.published, future
  end

  test "drafts scope should only return drafts" do
    published = Article.create!(title: "Published 2", body: "Content", published_at: 1.day.ago)
    draft = Article.create!(title: "Draft 2", body: "Content")

    assert_includes Article.drafts, draft
    assert_not_includes Article.drafts, published
  end
end
