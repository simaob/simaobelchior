require "test_helper"
require "fugit"

class DeleteOldVisitorSaltsJobTest < ActiveJob::TestCase
  test "deletes yesterday's salt even when nobody visits today" do
    travel_to Time.zone.local(2026, 11, 9, 22) do
      PageView.record(path: "/", referrer: nil, host: "simaobelchior.com", ip: "203.0.113.7", user_agent: "Chrome")
    end

    travel_to Time.zone.local(2026, 11, 10, 0, 1) do
      DeleteOldVisitorSaltsJob.perform_now
    end

    assert_empty VisitorSalt.all
    assert_equal 1, PageView.count
  end

  test "keeps today's salt" do
    travel_to Time.zone.local(2026, 11, 10, 9) do
      salt = VisitorSalt.for(Date.current)
      DeleteOldVisitorSaltsJob.perform_now

      assert_equal salt, VisitorSalt.for(Date.current)
    end
  end

  test "runs every 3 hours in production, starting just after midnight in Lisbon" do
    task = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "delete_old_visitor_salts")
    schedule = Fugit.parse(task["schedule"])

    assert_equal DeleteOldVisitorSaltsJob, task["class"].constantize
    assert_kind_of Fugit::Cron, schedule
    assert_equal 3.hours.to_i, schedule.rough_frequency
    next_run = schedule.next_time(EtOrbi.parse("2026-07-14 23:30 Europe/Lisbon"))
    assert_equal Time.zone.local(2026, 7, 15, 0, 1), Time.zone.at(next_run.to_i)
  end
end
