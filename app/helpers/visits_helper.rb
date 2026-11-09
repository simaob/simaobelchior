module VisitsHelper
  NICE_STEPS = [ 1, 6/5r, 3/2r, 2, 5/2r, 3, 4, 5, 6, 8, 10 ]

  # A round number at or just above the busiest day, for the top of the chart
  # (8 -> 8, 37 -> 40, 105 -> 120)
  def chart_ceiling(max)
    return 1 if max < 1

    magnitude = 10**Math.log10(max).floor
    NICE_STEPS.map { |step| step * magnitude }.find { |value| value >= max && value.to_i == value }.to_i
  end

  def bar_height(value, ceiling)
    "#{(100.0 * value / ceiling).round(2)}%"
  end
end
