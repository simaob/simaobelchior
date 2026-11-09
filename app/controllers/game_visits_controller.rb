# Counts visits to the games on games.simaobelchior.com. That site only serves static
# files, so each game page sends a beacon here when it opens. The visit is stored like
# a page view on this site, with no cookies and no IP address kept. See PageView.
class GameVisitsController < ApplicationController
  GAMES_ORIGIN = "https://#{PageView::GAMES_HOST}".freeze
  GAME_PATH = %r{\A/[\w\-./]{0,200}\z}

  # The beacon comes from the games' subdomain, so it can't carry this site's CSRF
  # token. The worst a forged request can do is add a count.
  skip_forgery_protection

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

  # Skips requests from anywhere but the games, paths that aren't plain paths, bots,
  # and the site owner while logged in
  def countable?
    request.origin == GAMES_ORIGIN && params[:path].is_a?(String) && params[:path].match?(GAME_PATH) &&
      !logged_in? && !PageView.bot?(request.user_agent)
  end
end
