class ArticlesController < ApplicationController
  READING_LIST_TAG = "reading-list"

  def index
    @articles = Article.published.includes(:tags)

    # Filter by tag if specified
    if params[:tag].present?
      @tag = Tag.find_by(name: params[:tag].downcase)
      @articles = @articles.joins(:tags).where(tags: { id: @tag.id }) if @tag
    end

    # Paginate (15 articles per page)
    @articles = @articles.page(params[:page]).per(15)

    @topic_tags = Tag.joins(:articles)
                     .where(articles: { published_at: ..Time.current })
                     .group(:id)
                     .order(Arel.sql("COUNT(articles.id) DESC"), :name)
                     .limit(8)
    @featured = Article.published.featured.first
    @latest_reading_list = Article.published.joins(:tags).find_by(tags: { name: READING_LIST_TAG })
  end

  def show
    @article = Article.published.find_by!(slug: params[:slug])
    @older = @article.older
    @newer = @article.newer
  end

  def feed
    @articles = Article.published.includes(:tags).limit(20)
    respond_to do |format|
      format.rss { render layout: false }
    end
  end
end
