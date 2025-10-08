class ArticlesController < ApplicationController
  def index
    @articles = Article.published.includes(:tags)

    # Filter by tag if specified
    if params[:tag].present?
      @tag = Tag.find_by(name: params[:tag].downcase)
      @articles = @articles.joins(:tags).where(tags: { id: @tag.id }) if @tag
    end

    # Paginate (15 articles per page)
    @articles = @articles.page(params[:page]).per(15)
  end

  def show
    @article = Article.published.find_by!(slug: params[:slug])
  end
end
