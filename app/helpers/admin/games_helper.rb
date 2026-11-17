module Admin::GamesHelper
  def game_share(rate)
    number_to_percentage(rate * 100, precision: 0) if rate
  end

  # Medians of an even count can land on a half
  def format_moves(moves)
    return nil if moves.nil?

    moves == moves.to_i ? moves.to_i.to_s : number_with_precision(moves, precision: 1)
  end
end
