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
    assert_focus_on "a.attachment__zoom"

    find("a.attachment__zoom").click
    find("button.image-zoom__close").click
    assert_no_selector "dialog.image-zoom"
    assert_focus_on "a.attachment__zoom"
  end

  test "zooming in and out with the keyboard" do
    visit article_path(@article.slug)
    find("a.attachment__zoom").send_keys(:enter)
    assert_selector "dialog.image-zoom[open] img[role=button][aria-pressed=false]"

    send_keys :tab
    assert_focus_on "dialog.image-zoom img"
    send_keys :enter
    assert_selector "dialog.image-zoom.is-zoomed img[aria-pressed=true]"

    send_keys :arrow_right
    assert_operator evaluate_script("document.querySelector('dialog.image-zoom').scrollLeft"), :>, 0

    send_keys :space
    assert_no_selector "dialog.image-zoom.is-zoomed"

    send_keys :escape
    assert_no_selector "dialog.image-zoom"
    assert_focus_on "a.attachment__zoom"
  end

  private

  def assert_focus_on(selector)
    assert evaluate_script("document.activeElement.matches(#{selector.to_json})"), "Expected focus on #{selector}"
  end
end
