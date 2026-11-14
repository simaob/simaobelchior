# What's happening: today's visits, the articles people are reading this week, sites
# linking here for the first time, and the writing in progress. The Visits page has the rest.
class Admin::DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @today = VisitStats.new(period: "today")
    @today_by_site = VisitStats::SITES.keys.excluding("all").index_with { |site| VisitStats.new(period: "today", site: site).totals.visits }
    @month = VisitStats.new(period: "30d")

    week = VisitStats.new(period: "7d")
    @popular = week.articles(limit: 5)
    @new_referrers = week.new_referrers(limit: 5).map { |referrer| [ referrer, week.landing_page(referrer.host) ] }

    @drafts = Article.unpublished.with_rich_text_body.order(updated_at: :desc).limit(5)
    @recently_published = Article.published.limit(5)
    @visits = PageView.site.visits_by_path(@recently_published.map { |article| article_path(article.slug) })
    @article_counts = { total: Article.count, published: Article.published.count, unpublished: Article.unpublished.count }
  end
end
