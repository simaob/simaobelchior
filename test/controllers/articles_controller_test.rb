require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  test "should get blog index" do
    get blog_path
    assert_response :success
    assert_select "h1", "Notes, now and then."
  end

  test "should display published articles on index" do
    published = Article.create!(title: "My Published Article", body: "Content", published_at: 1.day.ago)
    draft = Article.create!(title: "My Draft Article", body: "Content", published_at: nil)

    get blog_path
    assert_response :success
    assert_select "h2 a", text: "My Published Article"
    assert_select "h2 a", text: "My Draft Article", count: 0
  end

  test "should filter articles by tag" do
    tag = Tag.create!(name: "ruby")
    article1 = Article.create!(title: "Ruby Article", body: "Content", published_at: 1.day.ago)
    article1.tags << tag

    article2 = Article.create!(title: "Other Article", body: "Content", published_at: 1.day.ago)

    get blog_path(tag: "ruby")
    assert_response :success
    assert_select "h2 a", text: "Ruby Article"
    assert_select "h2 a", text: "Other Article", count: 0
    assert_select "h1", text: /tagged with "ruby"/
  end

  test "should show article by slug" do
    article = Article.create!(title: "Test Article", body: "Test content", published_at: 1.day.ago)

    get article_path(article.slug)
    assert_response :success
    assert_select "h1", "Test Article"
    assert_select ".author-card img.author-card__avatar[src=?]", "/images/simao_avatar.jpg"
    assert_select ".author-card a[href*='github.com/sponsors']", count: 0
    assert_select ".site-footer--cta a[href=?]", "https://github.com/sponsors/simaob?frequency=one-time", text: "Buy me a coffee"
  end

  test "should not show unpublished article" do
    article = Article.create!(title: "Unpublished Draft Post", body: "Content", published_at: nil)

    get article_path(article.slug)
    assert_response :not_found
  end

  test "should display article tags" do
    article = Article.create!(title: "Tagged Article", body: "Content", published_at: 1.day.ago)
    article.tag_list = "ruby, rails"
    article.save!

    get article_path(article.slug)
    assert_response :success
    assert_select ".chip", text: "ruby"
    assert_select ".chip", text: "rails"
  end

  test "should show reading time on article" do
    article = Article.create!(title: "Long Read", body: "word " * 450, published_at: 1.day.ago)

    get article_path(article.slug)
    assert_select ".article-meta", text: /3 min read/
  end

  test "should link to older and newer articles" do
    older = Article.create!(title: "Older Post", body: "Content", published_at: 3.days.ago)
    article = Article.create!(title: "Middle Post", body: "Content", published_at: 2.days.ago)
    newer = Article.create!(title: "Newer Post", body: "Content", published_at: 1.day.ago)

    get article_path(article.slug)
    assert_select ".article-nav a[href=?]", article_path(older.slug), text: /Older Post/
    assert_select ".article-nav a[href=?]", article_path(newer.slug), text: /Newer Post/
  end

  test "should search articles" do
    Article.create!(title: "Hotwire Notes", body: "Content", published_at: 1.day.ago)
    Article.create!(title: "Other Article", body: "Content", published_at: 1.day.ago)
    Article.create!(title: "Hotwire Draft", body: "Content", published_at: nil)

    get blog_path(q: "hotwire")
    assert_response :success
    assert_select "h1", text: /matching "hotwire"/
    assert_select "h2 a", text: "Hotwire Notes"
    assert_select "h2 a", text: "Other Article", count: 0
    assert_select "h2 a", text: "Hotwire Draft", count: 0
    assert_select "input[name=q][value=?]", "hotwire"
    assert_select "meta[name=robots][content=noindex]"
    assert_select ".tag-filter a[aria-current]", count: 0
  end

  test "should say when a search finds nothing" do
    get blog_path(q: "nothing like this")
    assert_response :success
    assert_select ".empty-state", text: /No articles found/
    assert_select ".empty-state a[href=?]", blog_path
  end

  test "should show everything for a blank search" do
    Article.create!(title: "Any Article", body: "Content", published_at: 1.day.ago)

    get blog_path(q: "  ")
    assert_select "h1", "Notes, now and then."
    assert_select "h2 a", text: "Any Article"
    assert_select "meta[name=robots]", count: 0
  end

  test "should show topic filters with the active tag marked" do
    tag = Tag.create!(name: "ruby")
    Article.create!(title: "Ruby Article", body: "Content", published_at: 1.day.ago).tags << tag

    get blog_path(tag: "ruby")
    assert_select ".tag-filter a[aria-current=page]", text: "ruby"
  end

  test "should show featured article under start here" do
    Article.create!(title: "Read This First", body: "Content", published_at: 1.day.ago, featured: true)

    get blog_path
    assert_select ".side-card", text: /Start here/
    assert_select ".side-card a", text: "Read This First"
  end

  test "should show latest reading list" do
    tag = Tag.create!(name: "reading-list")
    Article.create!(title: "September Stars", body: "Content", published_at: 2.days.ago).tags << tag
    Article.create!(title: "October Stars", body: "Content", published_at: 1.day.ago).tags << tag

    get blog_path
    assert_select ".side-card a", text: "October Stars"
  end

  test "should point to the blogroll once it has links" do
    get blog_path
    assert_select ".blog-layout__aside .side-card a[href=?]", blogroll_path, text: "See the blogroll →"

    Link.delete_all
    get blog_path
    assert_select ".blog-layout__aside", count: 0
  end

  test "should show articles in full on the index, with players for YouTube links" do
    Article.create!(title: "Music", body: %(<div><a href="https://youtu.be/kNbgap22Jr8">https://youtu.be/kNbgap22Jr8</a></div>), published_at: 1.day.ago)
    Article.create!(title: "Note", body: "<ol><li>First</li><li>Second</li></ol>", published_at: 2.days.ago)

    get blog_path
    assert_select ".post-entry__body figure.video-embed iframe[src=?]", "https://www.youtube-nocookie.com/embed/kNbgap22Jr8"
    assert_select ".post-entry__body ol li", count: 2
    assert_select ".post-entry__more", count: 0
  end

  test "should cut long articles short on the index with a link to the rest" do
    article = Article.create!(title: "Long Read", body: "word " * 201, published_at: 1.day.ago)

    get blog_path
    assert_select ".post-entry__body--cut", count: 1
    assert_select ".post-entry__more[href=?]", article_path(article.slug), text: "Continue reading →"
  end

  test "should show the sidebar on articles, but not point to the article itself" do
    featured = Article.create!(title: "Start Here", body: "Content", published_at: 2.days.ago, featured: true)
    other = Article.create!(title: "Other", body: "Content", published_at: 1.day.ago)

    get article_path(other.slug)
    assert_select ".blog-layout__aside .side-card a", text: "Start Here"

    get article_path(featured.slug)
    assert_select ".blog-layout__aside .side-card a", text: "Start Here", count: 0
  end

  test "should paginate with older and newer links" do
    16.times { |i| Article.create!(title: "Post #{i}", body: "Content", published_at: (i + 1).hours.ago) }

    get blog_path
    assert_select ".post-pagination", text: /Page 1 of 2/
    assert_select ".post-pagination a[rel=next]", text: "Older posts →"
  end

  test "should show YouTube links on their own line as a player, but keep the link in RSS" do
    article = Article.create!(title: "Music", body: %(<div><a href="https://youtu.be/kNbgap22Jr8">https://youtu.be/kNbgap22Jr8</a></div>), published_at: 1.day.ago)

    get article_path(article.slug)
    assert_select ".article-content figure.video-embed iframe[src=?]", "https://www.youtube-nocookie.com/embed/kNbgap22Jr8"

    get blog_feed_path(format: :rss)
    assert_match "https://youtu.be/kNbgap22Jr8", @response.body
    assert_no_match "<iframe", @response.body
  end

  test "should render articles with attachments for models that no longer exist" do
    gid = URI::GID.build(app: GlobalID.app, model_name: "Embed", model_id: "1")
    sgid = SignedGlobalID.new(gid, for: ActionText::Attachable::LOCATOR_NAME).to_s
    article = Article.create!(
      title: "Old Embed",
      body: %(<div><action-text-attachment sgid="#{sgid}" content="YouTube Video"></action-text-attachment>Content</div>),
      published_at: 1.day.ago
    )

    get blog_path
    assert_response :success
    assert_select ".post-entry__body", text: /Content/

    get article_path(article.slug)
    assert_response :success

    get blog_feed_path(format: :rss)
    assert_response :success
  end

  test "should link article images to a larger copy" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("public/images/simao_avatar.jpg").open, filename: "photo.jpg", content_type: "image/jpeg"
    )
    article = Article.create!(
      title: "With a Photo",
      body: %(<action-text-attachment sgid="#{blob.attachable_sgid}" caption="Porto"></action-text-attachment>),
      published_at: 1.day.ago
    )

    get article_path(article.slug)
    assert_response :success
    assert_select ".lexxy-content[data-controller~=image-zoom][data-action='click->image-zoom#open']"
    assert_select "figure.attachment--preview a.attachment__zoom[title='Enlarge image']" do |links|
      assert_match %r{/rails/active_storage/representations/}, links.first["href"]
      assert_select "img[src*='/rails/active_storage/representations/']"
    end
    assert_select "figcaption", "Porto"
  end

  test "should generate RSS feed" do
    get blog_feed_path(format: :rss)
    assert_response :success
    assert_equal "application/rss+xml", @response.media_type
  end

  test "counts feed readers fetching the feed, but not browsers or the site owner" do
    get blog_feed_path, headers: { "User-Agent" => "Feedly/1.0 (+http://www.feedly.com/fetcher.html; 37 subscribers; like FeedFetcher-Google)" }
    get blog_feed_path, headers: { "User-Agent" => "NetNewsWire (RSS Reader; https://netnewswire.com/)" }
    get blog_feed_path, headers: { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36" }
    assert_response :success
    assert_equal({ "Feedly" => 37, "NetNewsWire" => 1 }, FeedFetch.readers_on(Date.current))
    assert_equal 0, PageView.count

    post login_path, params: { email: "user1@example.com", password: "password" }
    get blog_feed_path, headers: { "User-Agent" => "Reeder/5050.01.00 CFNetwork/1568.100.1 Darwin/24.0.0" }
    assert_equal 2, FeedFetch.count
  end

  test "RSS feed should include published articles" do
    published = Article.create!(title: "Published Article", body: "Content for RSS", published_at: 1.day.ago)
    draft = Article.create!(title: "Draft Article", body: "Content", published_at: nil)

    get blog_feed_path(format: :rss)
    assert_response :success

    assert_match "Published Article", @response.body
    assert_no_match "Draft Article", @response.body
  end

  test "RSS feed should limit to 20 articles" do
    25.times do |i|
      Article.create!(title: "Article #{i}", body: "Content #{i}", published_at: i.days.ago)
    end

    get blog_feed_path(format: :rss)
    assert_response :success

    # RSS feed should only include 20 articles
    Article.published.limit(20).each do |article|
      assert_match article.title, @response.body
    end
  end

  test "RSS feed should include article metadata" do
    tag = Tag.create!(name: "testing")
    article = Article.create!(
      title: "Test RSS Article",
      body: "This is RSS test content",
      published_at: 1.day.ago
    )
    article.tags << tag

    get blog_feed_path(format: :rss)
    assert_response :success

    # Check for RSS structure
    assert_match "<title>Test RSS Article</title>", @response.body
    assert_match "<category>testing</category>", @response.body
    assert_match "<author>Simão Belchior</author>", @response.body
    assert_match article_url(article.slug), @response.body
  end
end
