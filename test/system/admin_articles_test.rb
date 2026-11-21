require "application_system_test_case"

class AdminArticlesTest < ApplicationSystemTestCase
  setup do
    User.create!(email: "admin@simaobelchior.com", password: "password123", password_confirmation: "password123")
  end

  test "writing and publishing an article with the Lexxy editor" do
    log_in
    visit new_admin_article_path
    fill_in "Title", with: "Written in Lexxy"
    find("lexxy-editor [contenteditable]").click.send_keys("A paragraph with **bold** text", :enter, "https://youtu.be/kNbgap22Jr8", :enter)
    click_on "Create Article"
    assert_text "Written in Lexxy"

    article = Article.find_by!(title: "Written in Lexxy")
    assert_includes article.body.to_s, "<strong>bold</strong>"

    article.update!(published_at: 1.minute.ago)
    visit article_path(article.slug)
    assert_selector ".lexxy-content strong", text: "bold"
    assert_selector "figure.video-embed iframe[src='https://www.youtube-nocookie.com/embed/kNbgap22Jr8']"
  end

  test "picking existing tags and catching near duplicates" do
    Article.create!(title: "On Rails", body: "Content", tag_list: "rails, action-text")
    Article.create!(title: "More Rails", body: "Content", tag_list: "rails")

    log_in
    visit new_admin_article_path
    fill_in "Title", with: "Tagged"

    tags = find_field("Tags")
    tags.send_keys("ra")
    assert_selector "#tag-suggestions .dropdown-item.active", text: "rails"
    tags.send_keys(:enter)
    assert_equal "rails, ", tags.value

    tags.send_keys("action text, ")
    warnings = find("[data-tag-input-target=warnings]")
    assert_equal "“action text” would be a new tag. Did you mean action-text?", warnings.text
    warnings.click_on "action-text"
    assert_equal "rails, action-text", tags.value
    assert_no_selector "[data-tag-input-target=warnings]", visible: true

    chip = ->(name) { find("[data-tag-input-target=chip][data-tag-input-name-param=#{name}]") }
    assert_equal "true", chip["rails"]["aria-pressed"]
    chip["rails"].click
    assert_equal "action-text", tags.value
    assert_equal "false", chip["rails"]["aria-pressed"]

    click_on "Create Article"
    assert_text "Article was successfully created."
    assert_equal [ "action-text" ], Article.find_by!(title: "Tagged").tags.map(&:name)
  end

  private

  def log_in
    visit login_path
    fill_in "Email", with: "admin@simaobelchior.com"
    fill_in "Password", with: "password123"
    click_on "Log In"
    assert_text "Logged in successfully"
  end
end
