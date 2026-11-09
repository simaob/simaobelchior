# All the visit stats, for this site and for the games. The dashboard only shows a glimpse of each.
class Admin::VisitsController < ApplicationController
  before_action :require_authentication

  def site
    @summary = PageView.site.summary
  end

  def games
    @summary = PageView.games.summary
  end
end
