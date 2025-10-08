require "test_helper"

class Admin::ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_or_create_by!(email: "admin@simaobelchior.com") do |user|
      user.password = "password123"
      user.password_confirmation = "password123"
    end
    post login_path, params: { email: @user.email, password: "password123" }
    @article = Article.create!(title: "Test Article", body: "Test content", published_at: 1.day.ago)
  end

  test "should require authentication for index" do
    delete logout_path
    get admin_articles_path
    assert_redirected_to login_path
  end

  test "should get index" do
    get admin_articles_path
    assert_response :success
  end

  test "should filter articles by status" do
    Article.create!(title: "Draft Article", body: "Draft content")
    get admin_articles_path(status: "published")
    assert_response :success
  end

  test "should get new" do
    get new_admin_article_path
    assert_response :success
  end

  test "should create article" do
    assert_difference("Article.count") do
      post admin_articles_path, params: {
        article: {
          title: "New Article",
          body: "New content",
          tag_list: "ruby, rails"
        }
      }
    end
    assert_redirected_to admin_articles_path
  end

  test "should not create article with invalid data" do
    assert_no_difference("Article.count") do
      post admin_articles_path, params: {
        article: { title: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_admin_article_path(@article)
    assert_response :success
  end

  test "should update article" do
    patch admin_article_path(@article), params: {
      article: { title: "Updated Title" }
    }
    assert_redirected_to admin_articles_path
    @article.reload
    assert_equal "Updated Title", @article.title
  end

  test "should not update article with invalid data" do
    patch admin_article_path(@article), params: {
      article: { title: "" }
    }
    assert_response :unprocessable_entity
  end

  test "should destroy article" do
    assert_difference("Article.count", -1) do
      delete admin_article_path(@article)
    end
    assert_redirected_to admin_articles_path
  end

  test "should toggle publish status" do
    draft = Article.create!(title: "Draft", body: "Content")
    assert_nil draft.published_at

    post toggle_publish_admin_article_path(draft)
    draft.reload
    assert_not_nil draft.published_at

    post toggle_publish_admin_article_path(draft)
    draft.reload
    assert_nil draft.published_at
  end
end
