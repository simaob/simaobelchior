class Admin::DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @site_days = VisitStats.new(period: "30d", site: "site").buckets
    @game_days = VisitStats.new(period: "30d", site: "games").buckets

    @total_articles = Article.count
    @published_count = Article.published.count
    @draft_count = Article.drafts.count
    @recent_articles = Article.order(created_at: :desc).limit(10)
    @visits = PageView.site.visits_by_path(@recent_articles.map { |article| article_path(article.slug) })
  end
end
