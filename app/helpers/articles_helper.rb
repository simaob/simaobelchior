module ArticlesHelper
  def article_meta(article)
    date = tag.time(article.published_at.strftime("%-d %B %Y"), datetime: article.published_at.iso8601)
    safe_join([ date, "#{article.reading_minutes} min read" ], " · ")
  end
end
