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
end
