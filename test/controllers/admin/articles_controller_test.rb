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

  test "shows visits to each article" do
    draft = Article.create!(title: "Draft Article", body: "Draft content")
    2.times { |i| PageView.record(path: "/blog/#{@article.slug}", referrer: nil, host: "simaobelchior.com", ip: "203.0.113.#{i}", user_agent: "Chrome") }
    PageView.record(path: "/blog/#{@article.slug}", referrer: nil, host: PageView::GAMES_HOST, ip: "203.0.113.9", user_agent: "Chrome")

    get admin_articles_path
    assert_select "tr", text: /#{@article.title}/ do
      assert_select ".article-visits", "2"
    end
    assert_select "tr", text: /#{draft.title}/ do
      assert_select ".article-visits", "0"
    end
  end

  test "sorts articles by visits, most visited first" do
    popular = Article.create!(title: "Popular", body: "Content", published_at: 3.days.ago, tag_list: "ruby")
    quiet = Article.create!(title: "Quiet", body: "Content", published_at: 2.days.ago, tag_list: "ruby")
    unread = Article.create!(title: "Unread", body: "Content", published_at: 1.hour.ago, tag_list: "ruby")
    visit = ->(article, ip, host: "simaobelchior.com") { PageView.record(path: "/blog/#{article.slug}", referrer: nil, host: host, ip: ip, user_agent: "Chrome") }
    3.times { |i| visit.(popular, "203.0.113.#{i}") }
    visit.(quiet, "203.0.113.1")
    5.times { |i| visit.(unread, "203.0.113.#{i}", host: PageView::GAMES_HOST) } # Not this site's

    get admin_articles_path(sort: "visits")
    assert_equal [ "Popular", "Quiet", "Unread", "Test Article" ], css_select("tbody tr td:first-child a").map(&:text)
    assert_select "select[name=sort] option[selected][value=visits]"

    get admin_articles_path(sort: "visits", tag: "ruby")
    assert_equal [ "Popular", "Quiet", "Unread" ], css_select("tbody tr td:first-child a").map(&:text)

    # The published scope sorts by date first, which the visits sort replaces
    get admin_articles_path(sort: "visits", status: "published")
    assert_equal [ "Popular", "Quiet", "Unread", "Test Article" ], css_select("tbody tr td:first-child a").map(&:text)
  end

  test "sorts filtered articles by title" do
    Article.create!(title: "Another Article", body: "Content", published_at: 2.days.ago)

    get admin_articles_path(sort: "title", status: "published")
    assert_equal [ "Another Article", "Test Article" ], css_select("tbody tr td:first-child a").map(&:text)
  end

  test "should filter articles by status" do
    Article.create!(title: "Draft Article", body: "Draft content")
    get admin_articles_path(status: "published")
    assert_response :success
  end

  test "should get new" do
    get new_admin_article_path
    assert_response :success
    assert_select "lexxy-editor[name=?]", "article[body]"
    assert_select "trix-editor", count: 0
  end

  test "new article form offers the most used tags" do
    Article.create!(title: "Tagged", body: "Content", tag_list: "ruby, rails")
    Article.create!(title: "Also tagged", body: "Content", tag_list: "rails")

    get new_admin_article_path
    assert_select "[data-controller=tag-input]" do
      assert_select "button[data-tag-input-name-param]", 2
      assert_select "button[data-tag-input-name-param=rails]", text: /rails\s+2/
    end
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

  test "should mark article as featured" do
    patch admin_article_path(@article), params: {
      article: { featured: "1" }
    }
    assert_redirected_to admin_articles_path
    assert @article.reload.featured?
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
