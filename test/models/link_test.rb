require "test_helper"

class LinkTest < ActiveSupport::TestCase
  test "needs a name and an address" do
    link = Link.new
    assert_not link.valid?
    assert_includes link.errors[:name], "can't be blank"
    assert_includes link.errors[:url], "can't be blank"
  end

  test "adds https:// to addresses pasted without a scheme" do
    link = Link.create!(name: "Example", url: " example.com/blog ", feed_url: "example.com/feed.xml")
    assert_equal "https://example.com/blog", link.url
    assert_equal "https://example.com/feed.xml", link.feed_url
  end

  test "keeps http:// addresses as they are" do
    assert_equal "http://example.com/", Link.new(url: "http://example.com/").url
  end

  test "only takes web addresses" do
    [ "javascript:alert(1)", "ftp://example.com/", "https://" ].each do |address|
      link = Link.new(name: "Bad", url: address, feed_url: address)
      assert_not link.valid?, "#{address} should be rejected"
      assert link.errors[:url].any?
      assert link.errors[:feed_url].any?
    end
  end

  test "stores blank feeds and descriptions as nil" do
    link = Link.create!(name: "  Example  ", url: "https://example.com/", feed_url: "  ", description: " ")
    assert_equal "Example", link.name
    assert_nil link.feed_url
    assert_nil link.description
  end

  test "doesn't list the same address twice" do
    link = Link.new(name: "Ana again", url: "https://WWW.ana.example/")
    assert_not link.valid?
    assert_includes link.errors[:url], "has already been taken"
  end

  test "sorts by name, ignoring case" do
    assert_equal [ "Ana's Notes", "bea writes", "Zed" ], Link.alphabetical.map(&:name)
  end

  test "shows the domain without www." do
    assert_equal "ana.example", links(:ana).domain
    assert_equal "zed.example", links(:zed).domain
  end
end
