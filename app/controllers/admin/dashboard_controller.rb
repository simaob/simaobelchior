class Admin::DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @total_articles = Article.count
    @published_count = Article.published.count
    @draft_count = Article.drafts.count
    @recent_articles = Article.order(created_at: :desc).limit(10)
  end
end
