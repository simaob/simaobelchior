require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get root_path
    assert_response :success
    assert_select "h1", "I help engineering teams adopt AI without losing the craft."
    assert_select "#contact"
    assert_select "img.home-hero__photo[alt]"
  end

  test "home should link to past companies, with Switch pointing at Teya" do
    get root_path
    assert_select ".org-list a[href=?]", "https://mindera.com", text: "Mindera"
    assert_select ".org-list li", text: /Switch\s*now part of Teya/ do
      assert_select "a[href=?]", "https://www.teya.com", text: "Switch"
    end
  end

  test "home should use the plain footer" do
    get root_path
    assert_select ".site-footer--cta", count: 0
  end

  test "should get about" do
    get about_path
    assert_response :success
    assert_select "h1", "The longer story."
    assert_select ".chapter", 5
    assert_select ".site-nav a[aria-current=page]", text: "About"
  end

  test "about should use the call-to-action footer" do
    get about_path
    assert_select ".site-footer--cta a[href=?]", root_path(anchor: "contact")
  end
end
