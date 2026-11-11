# The blogroll: other people's sites, as a page and as OPML for feed readers
class LinksController < ApplicationController
  include CountsPageViews

  def index
    @links = Link.alphabetical

    respond_to do |format|
      format.html
      format.opml do
        @links = @links.with_feed
        send_data render_to_string(layout: false), type: :opml, disposition: "attachment", filename: "simaobelchior-blogroll.opml"
      end
    end
  end
end
