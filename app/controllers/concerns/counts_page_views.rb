# Counts visits to public pages on the server, with no JavaScript or cookies.
# See PageView for what is stored.
module CountsPageViews
  extend ActiveSupport::Concern

  included do
    after_action :count_page_view, if: :countable_page_view?
  end

  private

  def count_page_view
    PageView.record(
      path: request.path,
      referrer: request.referer,
      host: request.host,
      ip: request.remote_ip,
      user_agent: request.user_agent
    )
  rescue ActiveRecord::ActiveRecordError => error
    # A missed count shouldn't break the page
    Rails.logger.warn("Page view not counted: #{error.message}")
  end

  # Skips the site owner's visits while logged in, bots, and pages fetched ahead of a click
  def countable_page_view?
    request.get? && request.format.html? && response.successful? &&
      !logged_in? && !prefetch? && !PageView.bot?(request.user_agent)
  end

  def prefetch?
    %w[Sec-Purpose Purpose X-Sec-Purpose X-Moz].any? { |header| request.headers[header].to_s.include?("prefetch") }
  end
end
