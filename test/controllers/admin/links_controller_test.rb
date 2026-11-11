require "test_helper"

class Admin::LinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_path, params: { email: "user1@example.com", password: "password" }
  end

  test "needs a login" do
    delete logout_path

    get admin_links_path
    assert_redirected_to login_path

    assert_no_difference("Link.count") do
      post admin_links_path, params: { link: { name: "Sneaky", url: "https://sneaky.example/" } }
    end
    assert_redirected_to login_path
  end

  test "lists the links" do
    get admin_links_path
    assert_response :success
    assert_select "td a[href=?]", edit_admin_link_path(links(:ana)), text: "Ana's Notes"
    assert_select ".admin-bar a[aria-current=page]", text: "Blogroll"
  end

  test "adds a link" do
    get new_admin_link_path
    assert_response :success

    assert_difference("Link.count") do
      post admin_links_path, params: { link: { name: "Cy", url: "cy.example", feed_url: "", description: "Notes on Rails." } }
    end
    assert_redirected_to admin_links_path
    link = Link.find_by!(name: "Cy")
    assert_equal "https://cy.example", link.url
    assert_nil link.feed_url
  end

  test "shows what's wrong with a bad link" do
    assert_no_difference("Link.count") do
      post admin_links_path, params: { link: { name: "", url: "javascript:alert(1)" } }
    end
    assert_response :unprocessable_entity
    assert_select ".alert-danger li", text: "Name can't be blank"
  end

  test "updates a link" do
    get edit_admin_link_path(links(:zed))
    assert_response :success

    patch admin_link_path(links(:zed)), params: { link: { feed_url: "https://zed.example/rss" } }
    assert_redirected_to admin_links_path
    assert_equal "https://zed.example/rss", links(:zed).reload.feed_url
  end

  test "doesn't save a bad update" do
    patch admin_link_path(links(:zed)), params: { link: { url: "" } }
    assert_response :unprocessable_entity
    assert_equal "https://zed.example/", links(:zed).reload.url
  end

  test "removes a link" do
    assert_difference("Link.count", -1) do
      delete admin_link_path(links(:zed))
    end
    assert_redirected_to admin_links_path
  end
end
