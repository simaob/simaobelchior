# Records what happens inside the games on games.simaobelchior.com, one beacon per
# event, like a level started, finished or left. Each game picks its own events and
# details. See GameEvent for what's kept, and Admin::GamesController for the numbers.
class GameEventsController < ApplicationController
  include GameBeacon

  MAX_DATA_BYTES = 2_000

  def create
    record_event if from_a_player? && plain_text?
    head :no_content
  end

  private

  def record_event
    GameEvent.record(
      game: params[:game],
      level: params[:level].presence,
      name: params[:name],
      data: data,
      ip: request.remote_ip,
      user_agent: request.user_agent
    )
  rescue ActiveRecord::ActiveRecordError => error
    # A missed event shouldn't matter to the game
    Rails.logger.warn("Game event not recorded: #{error.message}")
  end

  def plain_text?
    params[:game].is_a?(String) && params[:name].is_a?(String) && (params[:level].nil? || params[:level].is_a?(String))
  end

  # The details come as a small JSON object. Anything else is dropped, not the event.
  def data
    raw = params[:data]
    return {} unless raw.is_a?(String) && raw.bytesize <= MAX_DATA_BYTES

    JSON.parse(raw)
  rescue JSON::ParserError
    {}
  end
end
