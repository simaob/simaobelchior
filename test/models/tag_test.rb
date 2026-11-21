require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "should require name" do
    tag = Tag.new
    assert_not tag.valid?
    assert_includes tag.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    Tag.create!(name: "rails")
    tag = Tag.new(name: "rails")
    assert_not tag.valid?
    assert_includes tag.errors[:name], "has already been taken"
  end

  test "should normalize name to lowercase and strip whitespace" do
    tag = Tag.create!(name: "  Ruby On Rails  ")
    assert_equal "ruby on rails", tag.name
  end

  test "should create tags from comma-separated list" do
    tags = Tag.from_list("ruby, rails, programming")
    assert_equal 3, tags.length
    assert_equal [ "programming", "rails", "ruby" ], tags.map(&:name).sort
  end

  test "should handle duplicate tags in list" do
    Tag.create!(name: "ruby")
    tags = Tag.from_list("ruby, rails, ruby")
    assert_equal 2, tags.length
    assert_equal 2, Tag.count
  end

  test "should handle empty and whitespace entries in list" do
    tags = Tag.from_list("ruby, , rails,  , javascript")
    assert_equal 3, tags.length
    assert_equal [ "javascript", "rails", "ruby" ], tags.map(&:name).sort
  end

  test "should return empty array for blank string" do
    assert_equal [], Tag.from_list("")
    assert_equal [], Tag.from_list(nil)
  end

  test "by_usage lists tags in use, most used first, with their article counts" do
    Article.create!(title: "One", body: "Content", tag_list: "ruby, rails")
    Article.create!(title: "Two", body: "Content", tag_list: "rails, hotwire")
    Article.create!(title: "Three", body: "Content", tag_list: "rails, ruby")
    Tag.create!(name: "unused")

    assert_equal [ [ "rails", 3 ], [ "ruby", 2 ], [ "hotwire", 1 ] ], Tag.by_usage.map { |tag| [ tag.name, tag.articles_count ] }
  end

  test "similar? matches the same tag spelt differently or with a typo" do
    assert Tag.similar?("action-text", "action text")
    assert Tag.similar?("llms", "llm")
    assert Tag.similar?("rails", "rials")
    assert Tag.similar?("javascript", "javasrcipt")
    assert_not Tag.similar?("ruby", "rust")
    assert_not Tag.similar?("ai", "ui")
    assert_not Tag.similar?("css", "cs")
  end

  test "lookalikes pairs each tag with the more used tag it looks like" do
    Article.create!(title: "One", body: "Content", tag_list: "llms, rails")
    Article.create!(title: "Two", body: "Content", tag_list: "llms, ruby")
    Article.create!(title: "Three", body: "Content", tag_list: "llm, action text")
    Article.create!(title: "Four", body: "Content", tag_list: "action-text")
    Article.create!(title: "Five", body: "Content", tag_list: "action-text")

    pairs = Tag.lookalikes.map { |less, more| [ less.name, more.name ] }
    assert_equal [ [ "action text", "action-text" ], [ "llm", "llms" ] ], pairs.sort
  end

  test "merge_into moves the articles to the other tag and deletes this one" do
    both = Article.create!(title: "Both", body: "Content", tag_list: "llm, llms")
    old = Article.create!(title: "Old", body: "Content", tag_list: "llm, ruby")
    llm, llms = Tag.find_by!(name: "llm"), Tag.find_by!(name: "llms")

    llm.merge_into(llms)

    assert_not Tag.exists?(llm.id)
    assert_equal [ "llms" ], both.reload.tags.map(&:name)
    assert_equal [ "llms", "ruby" ], old.reload.tags.map(&:name).sort
  end

  test "merge_into refuses to merge a tag into itself" do
    tag = Tag.create!(name: "ruby")
    assert_raises(ArgumentError) { tag.merge_into(tag) }
  end
end
