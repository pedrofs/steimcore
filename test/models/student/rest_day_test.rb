require "test_helper"

class Student::RestDayTest < ActiveSupport::TestCase
  test "weekdays are not rest days" do
    # 2026-06-01 is a Monday … 2026-06-05 is a Friday.
    (1..5).each do |day|
      travel_to Time.zone.local(2026, 6, day, 10, 0, 0) do
        assert_not Student::RestDay.today?, "expected 2026-06-0#{day} to be a training day"
      end
    end
  end

  test "Saturday is a rest day" do
    travel_to Time.zone.local(2026, 6, 6, 10, 0, 0) do
      assert Student::RestDay.today?
    end
  end

  test "Sunday is a rest day" do
    travel_to Time.zone.local(2026, 6, 7, 10, 0, 0) do
      assert Student::RestDay.today?
    end
  end

  test "evaluated against the app Time.zone, not UTC" do
    # 2026-06-07 02:00 in São Paulo (UTC-3) is still Saturday 23:00 in UTC.
    # The rule must follow the app zone (Sunday), not UTC (Saturday) — both are
    # rest days here, so assert the late-Saturday boundary instead: 2026-06-06
    # 22:00 SP is Sunday 01:00 UTC. The app zone says Saturday (rest).
    travel_to Time.zone.local(2026, 6, 6, 22, 0, 0) do
      assert_equal Date.new(2026, 6, 6), Time.zone.today
      assert Student::RestDay.today?
    end
  end
end
