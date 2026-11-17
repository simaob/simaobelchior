# How people get on with the games' levels: which they finish, which they give up on,
# and which they breeze through. See GameStats.
class Admin::GamesController < ApplicationController
  before_action :require_authentication

  def index
    @stats = GameStats.new(period: params[:period])
    @games = @stats.games
  end
end
