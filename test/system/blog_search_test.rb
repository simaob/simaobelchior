require "application_system_test_case"

class BlogSearchTest < ApplicationSystemTestCase
  setup do
    Article.create!(title: "Hotwire Notes", body: "Content", published_at: 2.days.ago)
    Article.create!(title: "Other Article", body: "Content", published_at: 1.day.ago)
  end

  test "searching, then clearing the box to see all articles again" do
    visit blog_path
    fill_in "Search writing", with: "hotwire\n"

    assert_selector "h1", text: 'Articles matching "hotwire"'
    assert_no_selector "h2 a", text: "Other Article"

    fill_in "Search writing", with: "", fill_options: { clear: :backspace }

    assert_selector "h1", text: "Notes, now and then."
    assert_selector "h2 a", text: "Other Article"
    assert evaluate_script("document.activeElement.name == 'q'"), "Expected the cursor to stay in the search box"
  end

  test "clearing the box with Escape" do
    visit blog_path(q: "hotwire")
    assert_no_selector "h2 a", text: "Other Article"

    find_field("Search writing").send_keys(:escape)

    assert_selector "h2 a", text: "Other Article"
  end

  test "emptying the box before searching doesn't search" do
    visit blog_path
    execute_script("document.addEventListener('submit', () => window.searched = true, true)")
    fill_in "Search writing", with: "hot"
    fill_in "Search writing", with: "", fill_options: { clear: :backspace }

    assert_not evaluate_script("window.searched")
  end
end
