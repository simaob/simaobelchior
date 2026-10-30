module ArticlesHelper
  YOUTUBE_HOSTS = %w[youtube.com www.youtube.com m.youtube.com music.youtube.com youtu.be www.youtu.be youtube-nocookie.com www.youtube-nocookie.com].freeze
  YOUTUBE_VIDEO_ID = /\A[\w-]{11}\z/
  YOUTUBE_PLAYER_PERMISSIONS = "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share".freeze

  def article_meta(article)
    date = tag.time(article.published_at.strftime("%-d %B %Y"), datetime: article.published_at.iso8601)
    safe_join([ date, "#{article.reading_minutes} min read" ], " · ")
  end

  # Renders the body with any YouTube link that sits on its own line turned into a player.
  # Action Text strips iframes when it sanitises the body, so the player is added afterwards,
  # built only from the validated video id and start time.
  def article_body(article)
    html = article.body.to_s
    return html unless html.include?("youtu")

    fragment = Nokogiri::HTML5.fragment(html)
    fragment.css("a[href]").each do |link|
      video = youtube_video(link["href"])
      embed_youtube_video(link, *video) if video && standalone_link?(link)
    end
    # A pasted address can also stay as plain text, alone in its paragraph
    fragment.css("p, div:not([class])").each do |block|
      video = youtube_video(block.text.strip) if block.element_children.empty?
      block.replace(youtube_player(*video)) if video
    end
    fragment.to_html.html_safe
  end

  private

  def youtube_video(url)
    uri = URI.parse(url)
    return unless uri.is_a?(URI::HTTP) && YOUTUBE_HOSTS.include?(uri.host&.downcase)

    params = URI.decode_www_form(uri.query.to_s).to_h
    video_id =
      if uri.host.end_with?("youtu.be") then uri.path.delete_prefix("/")
      elsif uri.path == "/watch" then params["v"]
      else uri.path[%r{\A/(?:embed|shorts|live)/([^/]+)}, 1]
      end
    [ video_id, youtube_start(params["t"] || params["start"]) ] if video_id&.match?(YOUTUBE_VIDEO_ID)
  rescue URI::InvalidURIError
    nil
  end

  # Accepts "90", "90s" or "1m30s"
  def youtube_start(value)
    match = value.to_s.match(/\A(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s?)?\z/)
    seconds = match && (match[1].to_i * 3600 + match[2].to_i * 60 + match[3].to_i)
    seconds if seconds&.positive?
  end

  # A link is on its own line when nothing but whitespace separates it from a line break
  # or the edge of its paragraph. Links inside quotes or lists stay links.
  def standalone_link?(link)
    %w[div p].include?(link.parent&.name) &&
      adjacent_node(link, :previous_sibling).then { |node| node.nil? || node.name == "br" } &&
      adjacent_node(link, :next_sibling).then { |node| node.nil? || node.name == "br" }
  end

  def youtube_player(video_id, start, title = "")
    title = "YouTube video" if title.empty? || title.start_with?("http")
    src = "https://www.youtube-nocookie.com/embed/#{video_id}#{"?start=#{start}" if start}"
    tag.figure(class: "video-embed") do
      tag.iframe(src:, title:, loading: "lazy", allow: YOUTUBE_PLAYER_PERMISSIONS,
                 referrerpolicy: "strict-origin-when-cross-origin", allowfullscreen: true)
    end
  end

  def embed_youtube_video(link, video_id, start)
    player = youtube_player(video_id, start, link.text.strip)
    block = link.parent
    if block["class"].nil? && block.children.all? { |node| node == link || node.name == "br" || blank_text?(node) }
      block.replace(player)
    else
      %i[previous_sibling next_sibling].each do |direction|
        node = adjacent_node(link, direction)
        node.remove if node&.name == "br"
      end
      link.replace(player)
    end
  end

  def adjacent_node(node, direction)
    sibling = node.public_send(direction)
    sibling = sibling.public_send(direction) while sibling && blank_text?(sibling)
    sibling
  end

  def blank_text?(node)
    node.text? && node.text.strip.empty?
  end
end
