class Admin::ArticlesController < ApplicationController
  before_action :require_authentication
  before_action :set_article, only: [ :edit, :update, :destroy, :toggle_publish ]

  def index
    @articles = Article.all.includes(:tags)

    # Filter by status
    case params[:status]
    when "published"
      @articles = @articles.published
    when "drafts"
      @articles = @articles.drafts
    end

    # Filter by tag
    if params[:tag].present?
      @articles = @articles.joins(:tags).where(tags: { name: params[:tag].downcase })
    end

    # Sort. The status scopes come with an order of their own, so this replaces it.
    by_published_at = Arel.sql("published_at IS NULL ASC, published_at DESC") # nulls last
    case params[:sort]
    when "title"
      @articles = @articles.reorder(:title)
    when "created_at"
      @articles = @articles.reorder(created_at: :desc)
    when "visits"
      @articles = @articles.reorder(Arel.sql("(#{visits_to_each_article.to_sql}) DESC"), by_published_at)
    else
      @articles = @articles.reorder(by_published_at)
    end

    @articles = @articles.page(params[:page]).per(25)
    @visits = PageView.site.visits_by_path(@articles.map { |article| article_path(article.slug) })
  end

  def new
    @article = Article.new
  end

  def create
    @article = Article.new(article_params)

    if @article.save
      redirect_to admin_articles_path, notice: "Article was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @article.update(article_params)
      redirect_to admin_articles_path, notice: "Article was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @article.destroy
    redirect_to admin_articles_path, notice: "Article was successfully deleted."
  end

  def toggle_publish
    if @article.published?
      @article.update(published_at: nil)
      message = "Article unpublished."
    else
      @article.update(published_at: Time.current)
      message = "Article published."
    end

    redirect_to admin_articles_path, notice: message
  end

  private

  def set_article
    @article = Article.find(params[:id])
  end

  # The visits to an article's page as a subquery, counted the same way as PageView.visits_by_path
  def visits_to_each_article
    PageView.site
      .where("page_views.path = ? || articles.slug", "#{blog_path}/")
      .select("COUNT(DISTINCT page_views.visitor_hash)")
  end

  def article_params
    permitted = params.require(:article).permit(:title, :slug, :body, :published_at, :tag_list, :featured)

    # Fix timezone handling for datetime_local_field
    # The HTML5 datetime-local input doesn't include timezone info, and Rails
    # incorrectly interprets it as UTC. We need to treat it as the app's timezone.
    if permitted[:published_at].is_a?(String) && permitted[:published_at].present?
      # Parse the datetime string as if it's in the application's timezone
      permitted[:published_at] = Time.zone.parse(permitted[:published_at])
    end

    permitted
  end
end
