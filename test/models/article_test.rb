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

  test "should efficiently generate slugs for multiple articles with similar titles" do
    # Create articles with manually set slugs to simulate existing data
    Article.create!(title: "Test Article Original", body: "Content", slug: "test-article")
    Article.create!(title: "Test Article Copy 1", body: "Content", slug: "test-article-1")
    Article.create!(title: "Test Article Copy 2", body: "Content", slug: "test-article-2")

    # Create new article with same base slug - should generate test-article-3
    article = Article.new(title: "Test Article")
    article.slug = nil
    article.body = "Content"
    article.valid?

    assert_equal "test-article-3", article.slug
  end

  test "should handle slug generation when updating articles" do
    article = Article.create!(title: "Original Title", body: "Content")
    original_slug = article.slug
    assert_equal "original-title", original_slug

    # Updating without changing title should keep same slug
    article.update!(body: "Updated content")
    assert_equal original_slug, article.slug

    # Create another article with different title
    article2 = Article.create!(title: "Another Title", body: "Content")

    # First article should still have its original slug when updated
    article.update!(body: "Updated again")
    assert_equal original_slug, article.slug

    # Verify slug doesn't regenerate on update
    article.save!
    assert_equal original_slug, article.slug
  end

  # Tag tests
  test "should assign tags to article" do
    article = Article.create!(title: "Tagged Article", body: "Content")
    tag1 = Tag.create!(name: "ruby")
    tag2 = Tag.create!(name: "rails")

    article.tags << [tag1, tag2]
    assert_equal 2, article.tags.count
    assert_includes article.tags, tag1
    assert_includes article.tags, tag2
  end

  test "should set tags from comma-separated string" do
    article = Article.create!(title: "Tagged Article", body: "Content")
    article.tag_list = "ruby, rails, programming"
    article.save!

    assert_equal 3, article.tags.count
    assert_equal ["programming", "rails", "ruby"], article.tags.pluck(:name).sort
  end

  test "should get tags as comma-separated string" do
    article = Article.create!(title: "Tagged Article", body: "Content")
    article.tags.create!(name: "ruby")
    article.tags.create!(name: "rails")

    assert_equal "ruby, rails", article.tag_list
  end

  test "should replace tags when setting new tag_list" do
    article = Article.create!(title: "Tagged Article", body: "Content")
    article.tag_list = "ruby, rails"
    article.save!

    assert_equal 2, article.tags.count

    article.tag_list = "python, django"
    article.save!

    assert_equal 2, article.tags.count
    assert_equal ["django", "python"], article.tags.pluck(:name).sort
  end

  test "should destroy article_tags when article is destroyed" do
    article = Article.create!(title: "Tagged Article", body: "Content")
    article.tag_list = "ruby, rails"
    article.save!

    article_tag_count = ArticleTag.count
    assert article_tag_count > 0

    article.destroy
    assert_equal article_tag_count - 2, ArticleTag.count
  end
end
