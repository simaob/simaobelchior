class Admin::LinksController < ApplicationController
  before_action :require_authentication
  before_action :set_link, only: %i[edit update destroy]

  def index
    @links = Link.alphabetical
  end

  def new
    @link = Link.new
  end

  def create
    @link = Link.new(link_params)

    if @link.save
      redirect_to admin_links_path, notice: "#{@link.name} was added to the blogroll."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @link.update(link_params)
      redirect_to admin_links_path, notice: "#{@link.name} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @link.destroy
    redirect_to admin_links_path, notice: "#{@link.name} was removed from the blogroll."
  end

  private

  def set_link
    @link = Link.find(params[:id])
  end

  def link_params
    params.require(:link).permit(:name, :url, :feed_url, :description)
  end
end
