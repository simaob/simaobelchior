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

  # Visits today, this week and this month, from 30 daily VisitStats buckets. A
  # visit is one person on one day, so visits over several days are the sum of each day's
  def visit_totals(days)
    {
      "Today" => days.last.visits,
      "Last 7 days" => days.last(7).sum(&:visits),
      "Last 30 days" => days.sum(&:visits)
    }
  end

  # The Visits page with some filters changed. A nil drops that filter.
  def visits_path_for(stats, **changes)
    params = stats.to_params.merge(changes)
    admin_visits_path(params.reject { |key, value| value.nil? || VisitStats::DEFAULTS[key] == value })
  end

  def chart_title(unit)
    "Visits per #{unit}"
  end

  # What one bar covers, in its tooltip and the table under the chart
  def bucket_label(bucket)
    case bucket.unit
    when :hour then "#{bucket.starts.strftime("%H:00")}–#{(bucket.starts + 1.hour).strftime("%H:00")}"
    when :day then bucket.starts.strftime("%a %-d %b")
    when :week then "Week of #{bucket.starts.strftime("%-d %b %Y")}"
    when :month then bucket.starts.strftime("%B %Y")
    end
  end

  # Under the first and last bars
  def bucket_axis_label(bucket, last: false)
    case bucket.unit
    when :hour then bucket.starts.strftime("%H:00")
    when :day then last ? "Today" : bucket.starts.strftime("%-d %b")
    when :week then last ? "This week" : bucket.starts.strftime("%-d %b %Y")
    when :month then last ? "This month" : bucket.starts.strftime("%b %Y")
    end
  end

  # What the totals are set against, or nil for all time
  def comparison_label(stats)
    case stats.period
    when "all" then nil
    when "today" then "yesterday by this time"
    else "the previous #{VisitStats::PERIODS.fetch(stats.period)}"
    end
  end

  # "Up 18% on the previous 30 days", or nothing when there's nothing to compare with
  def change_from(current, previous, against)
    return if against.nil? || previous.nil?
    return tag.span("Nothing in #{against}", class: "visits-change") if previous.zero?

    percent = ((current - previous) * 100.0 / previous).round
    text, direction = if percent.positive? then [ "Up #{percent}%", "up" ]
    elsif percent.negative? then [ "Down #{percent.abs}%", "down" ]
    else [ "Same as", "same" ]
    end

    tag.span("#{text} #{"on " unless direction == "same"}#{against}", class: "visits-change visits-change--#{direction}")
  end

  def format_views_per_visit(value)
    number_with_precision(value, precision: 1, strip_insignificant_zeros: true)
  end

  # Where a page from the stats is, on this site or the games'
  def visited_page_url(page)
    page.games? ? "https://#{PageView::GAMES_HOST}#{page.path}" : page.path
  end

  def visited_page_site(page)
    page.games? ? "games" : "site"
  end

  # How long the bar behind a row is, against the row with the most visits
  def rank_bar_width(value, top)
    "#{top.zero? ? 0 : (100.0 * value / top).clamp(0, 100).round(1)}%"
  end
end
