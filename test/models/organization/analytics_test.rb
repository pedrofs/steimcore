require "test_helper"

class Organization::AnalyticsTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
  end

  test "each series has one gap-filled entry per day across the window" do
    travel_to Time.zone.local(2026, 6, 3, 10) do
      payload = Organization::Analytics.new(@organization, days: 14).to_h

      %i[training_sessions periodizations].each do |key|
        series = payload[key]
        assert_equal 14, series.length
        assert_equal "2026-05-21", series.first[:date]
        assert_equal "2026-06-03", series.last[:date]
      end
      assert payload[:training_sessions].all? { |d| d[:trainer].zero? && d[:student].zero? }
      assert payload[:periodizations].all? { |d| d[:count].zero? }
    end
  end

  test "splits each day's sessions by who initiated them" do
    travel_to Time.zone.local(2026, 6, 3, 10) do
      session(at: Time.zone.local(2026, 6, 2, 9), trainer: @trainer)  # trainer-led
      session(at: Time.zone.local(2026, 6, 2, 18), trainer: nil)      # student-initiated
      session(at: Time.zone.local(2026, 6, 2, 20), trainer: nil)      # student-initiated

      day = day_for(:training_sessions, "2026-06-02")

      assert_equal 1, day[:trainer]
      assert_equal 2, day[:student]
    end
  end

  test "counts both finished and still-active sessions on their start day" do
    travel_to Time.zone.local(2026, 6, 3, 10) do
      session(at: Time.zone.local(2026, 6, 1, 9), finished_at: Time.zone.local(2026, 6, 1, 10))
      session(at: Time.zone.local(2026, 6, 1, 11), finished_at: nil)

      assert_equal 2, day_for(:training_sessions, "2026-06-01")[:trainer]
    end
  end

  test "excludes sessions and periodizations older than the window" do
    travel_to Time.zone.local(2026, 6, 3, 10) do
      session(at: Time.zone.local(2026, 5, 1, 9))
      periodization(at: Time.zone.local(2026, 5, 1, 9))

      payload = Organization::Analytics.new(@organization).to_h

      assert payload[:training_sessions].all? { |d| d[:trainer].zero? && d[:student].zero? }
      assert_equal 0, payload[:periodizations].sum { |d| d[:count] }
    end
  end

  test "counts periodizations created per day" do
    travel_to Time.zone.local(2026, 6, 3, 10) do
      periodization(at: Time.zone.local(2026, 6, 2, 9))
      periodization(at: Time.zone.local(2026, 6, 2, 15))

      assert_equal 2, day_for(:periodizations, "2026-06-02")[:count]
    end
  end

  test "scopes strictly to the organization" do
    travel_to Time.zone.local(2026, 6, 3, 10) do
      other_org = Organization.create!(name: "Outra")
      other_student = other_org.students.create!(name: "Forasteiro")
      session(at: Time.zone.local(2026, 6, 2, 9), student: other_student)
      periodization(at: Time.zone.local(2026, 6, 2, 9), student: other_student)

      payload = Organization::Analytics.new(@organization).to_h

      assert payload[:training_sessions].all? { |d| d[:trainer].zero? && d[:student].zero? }
      assert_equal 0, payload[:periodizations].sum { |d| d[:count] }
    end
  end

  private
    def day_for(series, date)
      Organization::Analytics.new(@organization).to_h[series].find { |d| d[:date] == date }
    end

    # Sessions default to finished so multiple can share a student without
    # tripping the "one active session per student" partial unique index; the
    # day series counts by start day regardless of finished state.
    def session(at:, trainer: @trainer, student: @student, finished_at: at)
      TrainingSession.create!(
        student: student, trainer: trainer,
        workout_name_snapshot: "A", workout_position_snapshot: 1,
        blocks_snapshot: [], progress: [],
        created_at: at, updated_at: at, finished_at: finished_at
      )
    end

    def periodization(at:, student: @student)
      student.periodizations.create!(created_at: at, updated_at: at)
    end
end
