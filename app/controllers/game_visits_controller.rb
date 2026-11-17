# Counts visits to the games on games.simaobelchior.com. That site only serves static
# files, so each game page sends a beacon here when it opens. The visit is stored like
# a page view on this site, with no cookies and no IP address kept. See PageView.
class GameVisitsController < ApplicationController
  include GameBeacon

  GAME_PATH = %r{\A/[\w\-./]{0,200}\z}

  def create
    count_visit if countable?
    head :no_content
  end

  private

  def count_visit
    PageView.record(
      path: params[:path],
      referrer: params[:referrer],
      host: PageView::GAMES_HOST,
      ip: request.remote_ip,
      user_agent: request.user_agent
    )
  rescue ActiveRecord::ActiveRecordError => error
    # A missed count shouldn't matter to the game
    Rails.logger.warn("Game visit not counted: #{error.message}")
  end

  # Skips paths that aren't plain paths, on top of what GameBeacon skips
  def countable?
    from_a_player? && params[:path].is_a?(String) && params[:path].match?(GAME_PATH)
  end
end
