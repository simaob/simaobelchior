# All the visit stats, for this site, the games or both, over a period you pick.
# See VisitStats. The dashboard only shows a glimpse.
class Admin::VisitsController < ApplicationController
  TOP = 10
  ALL = 500

  before_action :require_authentication

  def index
    @stats = VisitStats.new(**params.permit(:period, :site, :page, :from).to_h.symbolize_keys)
    @pages, @more_pages = top(:pages)
    @referrers, @more_referrers = top(:referrers)
  end

  private

  # The top pages or referrers, and whether there are more than shown.
  # ?show=pages or ?show=referrers lists them all.
  def top(list)
    return [ @stats.public_send(list, limit: ALL), false ] if showing_all?(list)

    rows = @stats.public_send(list, limit: TOP + 1)
    [ rows.first(TOP), rows.size > TOP ]
  end

  def showing_all?(list)
    params[:show] == list.to_s
  end
  helper_method :showing_all?
end
