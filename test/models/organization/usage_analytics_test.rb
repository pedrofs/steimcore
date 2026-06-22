require "test_helper"

class Organization::UsageAnalyticsTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
  end

  test "active_students is gap-filled across the window" do
    travel_to Time.zone.local(2026, 6, 3, 10) do
      series = Organization::UsageAnalytics.new(@organization, days: 14).to_h[:active_students]

      assert_equal 14, series.length
      assert_equal "2026-05-21", series.first[:date]
      assert_equal "2026-06-03", series.last[:date]
      assert series.all? { |d| d[:count].zero? }
    end
  end

  test "counts distinct active students per day, scoped to the organization" do
    travel_to Time.zone.local(2026, 6, 3, 10) do
      event("student.home_viewed", at: Time.zone.local(2026, 6, 2, 9), entry_state: "can_start")
      event("student.session_started", at: Time.zone.local(2026, 6, 2, 18))
      # A second org's student must not leak in.
      outsider = Organization.create!(name: "Outra").students.create!(name: "Forasteiro")
      event("student.home_viewed", at: Time.zone.local(2026, 6, 2, 12), student: outsider, entry_state: "no_plan")

      assert_equal 1, day_for(:active_students, "2026-06-02")[:count]
    end
  end

  test "session funnel counts and rates" do
    travel_to Time.zone.local(2026, 6, 3, 10) do
      3.times { event("student.session_started", at: Time.zone.local(2026, 6, 2, 9)) }
      2.times { event("student.session_finished", at: Time.zone.local(2026, 6, 2, 10)) }
      event("student.session_cancelled", at: Time.zone.local(2026, 6, 2, 11))

      funnel = Organization::UsageAnalytics.new(@organization).to_h[:session_funnel]

      assert_equal 3, funnel[:started]
      assert_equal 2, funnel[:finished]
      assert_equal 1, funnel[:cancelled]
      assert_equal 67, funnel[:completion_rate]   # 2 / 3
      assert_equal 25, funnel[:abandonment_rate]  # 1 / (3 + 1)
    end
  end

  test "app_open_states distribution over the four entry states" do
    travel_to Time.zone.local(2026, 6, 3, 10) do
      event("student.home_viewed", at: Time.zone.local(2026, 6, 2, 9), entry_state: "can_start")
      event("student.home_viewed", at: Time.zone.local(2026, 6, 2, 10), entry_state: "can_start")
      event("student.home_viewed", at: Time.zone.local(2026, 6, 2, 11), entry_state: "rest_day")

      states = Organization::UsageAnalytics.new(@organization).to_h[:app_open_states]

      assert_equal %w[resume can_start rest_day no_plan], states.map { |s| s[:state] }
      assert_equal 2, states.find { |s| s[:state] == "can_start" }[:count]
      assert_equal 1, states.find { |s| s[:state] == "rest_day" }[:count]
      assert_equal 0, states.find { |s| s[:state] == "resume" }[:count]
    end
  end

  test "excludes events older than the window" do
    travel_to Time.zone.local(2026, 6, 3, 10) do
      event("student.home_viewed", at: Time.zone.local(2026, 5, 1, 9), entry_state: "can_start")

      assert_equal 0, Organization::UsageAnalytics.new(@organization).to_h[:totals][:events]
    end
  end

  private
    def event(name, at:, student: @student, **properties)
      Ahoy::Event.create!(
        visit: Ahoy::Visit.create!(started_at: at),
        name: name,
        time: at,
        properties: {
          organization_id: student.organization_id,
          student_id: student.id,
          student_identity_id: student.student_identity_id
        }.merge(properties)
      )
    end

    def day_for(series, date)
      Organization::UsageAnalytics.new(@organization).to_h[series].find { |d| d[:date] == date }
    end
end
