class Admin::DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @days = PageView.by_day(days: 30)
    @top_pages = PageView.top_pages(since: @days.first.day)
    @top_referrers = PageView.top_referrers(since: @days.first.day)

    @total_articles = Article.count
    @published_count = Article.published.count
    @draft_count = Article.drafts.count
    @recent_articles = Article.order(created_at: :desc).limit(10)
  end
end
