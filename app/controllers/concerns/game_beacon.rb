# For the beacons the games on games.simaobelchior.com send with navigator.sendBeacon.
# That site only serves static files, so this is how its games report back.
module GameBeacon
  extend ActiveSupport::Concern

  GAMES_ORIGIN = "https://#{PageView::GAMES_HOST}".freeze

  included do
    # The beacon comes from the games' subdomain, so it can't carry this site's CSRF
    # token. The worst a forged request can do is add a count.
    skip_forgery_protection
  end

  private

  # Sent by a game, and not by a bot or the site owner while logged in
  def from_a_player?
    request.origin == GAMES_ORIGIN && !logged_in? && !PageView.bot?(request.user_agent)
  end
end
