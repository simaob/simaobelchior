require "application_system_test_case"

class AdminArticlesTest < ApplicationSystemTestCase
  setup do
    User.create!(email: "admin@simaobelchior.com", password: "password123", password_confirmation: "password123")
  end

  test "writing and publishing an article with the Lexxy editor" do
    visit login_path
    fill_in "Email", with: "admin@simaobelchior.com"
    fill_in "Password", with: "password123"
    click_on "Log In"
    assert_text "Logged in successfully"

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
end
