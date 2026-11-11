xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.opml version: "2.0" do
  xml.head do
    xml.title "Simão Belchior's blogroll"
    xml.dateModified (@links.maximum(:updated_at) || Time.current).rfc822
    xml.ownerName "Simão Belchior"
    xml.ownerId root_url
    xml.docs "https://opml.org/spec2.opml"
  end
  xml.body do
    @links.each do |link|
      xml.outline type: "rss", text: link.name, title: link.name, xmlUrl: link.feed_url, htmlUrl: link.url, description: link.description
    end
  end
end
