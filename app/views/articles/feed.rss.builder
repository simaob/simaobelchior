xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title "Simão Belchior"
    xml.description "Personal blog by Simão Belchior - Ruby on Rails developer, entrepreneur, and builder"
    xml.link blog_url
    xml.tag! "atom:link", href: blog_feed_url(format: :rss), rel: "self", type: "application/rss+xml"
    xml.language "en-gb"
    xml.lastBuildDate @articles.first&.published_at&.rfc822 || Time.current.rfc822

    @articles.each do |article|
      xml.item do
        xml.title article.title
        xml.description do
          xml.cdata! article.body.to_s
        end
        xml.pubDate article.published_at.rfc822
        xml.link article_url(article.slug)
        xml.guid article_url(article.slug), isPermaLink: true
        xml.author "Simão Belchior"

        # Add categories for each tag
        article.tags.each do |tag|
          xml.category tag.name
        end
      end
    end
  end
end
