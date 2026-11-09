require "application_system_test_case"

class ArticleImageZoomTest < ApplicationSystemTestCase
  # The same markup as active_storage/blobs/_blob, with images from public/ so it doesn't depend on
  # Active Storage making variants (libvips isn't installed in CI)
  setup do
    @article = Article.create!(title: "Photo of Porto", published_at: 1.day.ago, body: <<~HTML)
      <p>A photo.</p>
      <figure class="attachment attachment--preview attachment--jpg">
        <a class="attachment__zoom" title="Enlarge image" href="/images/porto_sunset.jpg"><img src="/images/porto_sunset_1600.jpg"></a>
      </figure>
    HTML
  end

  test "opening an article image, zooming in and closing it" do
    visit article_path(@article.slug)
    find("a.attachment__zoom").click

    assert_selector "dialog.image-zoom[open].is-zoomable"
    assert_equal "http://#{page.server.host}:#{page.server.port}/images/porto_sunset.jpg", find("dialog.image-zoom img")[:src]

    find("dialog.image-zoom img").click
    assert_selector "dialog.image-zoom.is-zoomed"
    assert_equal 4618, evaluate_script("document.querySelector('dialog.image-zoom img').clientWidth")

    find("dialog.image-zoom img").click
    assert_no_selector "dialog.image-zoom.is-zoomed"

    send_keys :escape
    assert_no_selector "dialog.image-zoom"

    find("a.attachment__zoom").click
    find("button.image-zoom__close").click
    assert_no_selector "dialog.image-zoom"
  end
end
