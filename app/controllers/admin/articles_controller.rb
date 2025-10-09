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

    # Sort
    case params[:sort]
    when "title"
      @articles = @articles.order(:title)
    when "created_at"
      @articles = @articles.order(created_at: :desc)
    else # Default to published_at (nulls last)
      @articles = @articles.order(Arel.sql("published_at IS NULL ASC, published_at DESC"))
    end

    @articles = @articles.page(params[:page]).per(25)
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

  def article_params
    permitted = params.require(:article).permit(:title, :slug, :body, :published_at, :tag_list)

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
