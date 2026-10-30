require "test_helper"

class ArticlesHelperTest < ActionView::TestCase
  test "turns a YouTube link on its own line into a player" do
    html = article_body(Article.new(body: %(<div><a href="https://youtu.be/kNbgap22Jr8?si=abc"><em>https://youtu.be/kNbgap22Jr8?si=abc</em></a></div>)))

    assert_includes html, %(<figure class="video-embed"><iframe src="https://www.youtube-nocookie.com/embed/kNbgap22Jr8")
    assert_includes html, %(title="YouTube video")
    assert_not_includes html, "<a href"
  end

  test "supports watch links with a start time" do
    html = article_body(Article.new(body: %(<div><a href="https://www.youtube.com/watch?v=kNbgap22Jr8&amp;t=1m30s">Ao Ocaso</a></div>)))

    assert_includes html, %(src="https://www.youtube-nocookie.com/embed/kNbgap22Jr8?start=90")
    assert_includes html, %(title="Ao Ocaso")
  end

  test "embeds a link on its own line inside a paragraph and keeps the text around it" do
    html = article_body(Article.new(body: %(<div>Listen to this:<br><a href="https://youtu.be/kNbgap22Jr8">https://youtu.be/kNbgap22Jr8</a><br>So good.</div>)))

    assert_includes html, "Listen to this:"
    assert_includes html, "So good."
    assert_includes html, "youtube-nocookie.com/embed/kNbgap22Jr8"
    assert_not_includes html, "<br>"
  end

  test "leaves links that are part of a sentence alone" do
    html = article_body(Article.new(body: %(<div>I loved <a href="https://youtu.be/kNbgap22Jr8">this video</a> a lot.</div>)))

    assert_includes html, %(<a href="https://youtu.be/kNbgap22Jr8">this video</a>)
    assert_not_includes html, "<iframe"
  end

  test "leaves YouTube links inside quotes and lists alone" do
    html = article_body(Article.new(body: %(<blockquote><a href="https://youtu.be/kNbgap22Jr8">x</a></blockquote><ul><li><a href="https://youtu.be/kNbgap22Jr8">y</a></li></ul>)))

    assert_not_includes html, "<iframe"
  end

  test "leaves other links and malformed video ids alone" do
    html = article_body(Article.new(body: %(<div><a href="https://vimeo.com/123456">https://vimeo.com/123456</a></div><div><a href="https://www.youtube.com/watch?v=short">https://www.youtube.com/watch?v=short</a></div>)))

    assert_not_includes html, "<iframe"
    assert_includes html, %(href="https://vimeo.com/123456")
  end
end
