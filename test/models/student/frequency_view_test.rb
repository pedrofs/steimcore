require "test_helper"

class Student::FrequencyViewTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
  end

  test "window_end is the end of the current week and window_start is 26 weeks back padded to the start of that week" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      view = Student::FrequencyView.new(@student).to_h

      assert_equal Date.new(2026, 5, 17), view[:window_end]
      assert_equal Date.new(2025, 11, 17), view[:window_start]
      assert_equal 26 * 7, view[:days].length
      assert_equal view[:window_start], view[:days].first[:date]
      assert_equal view[:window_end], view[:days].last[:date]
    end
  end

  test "buckets finished sessions by created_at local-time date" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      morning  = finished_session_at(Time.zone.local(2026, 5, 13, 9, 0, 0))
      evening  = finished_session_at(Time.zone.local(2026, 5, 13, 22, 0, 0))
      previous = finished_session_at(Time.zone.local(2026, 5, 12, 8, 0, 0))

      view = Student::FrequencyView.new(@student).to_h
      by_date = view[:days].index_by { |d| d[:date] }

      assert_equal [ morning.id, evening.id ].sort,
                   by_date[Date.new(2026, 5, 13)][:sessions].map { |s| s[:id] }.sort
      assert_equal [ previous.id ],
                   by_date[Date.new(2026, 5, 12)][:sessions].map { |s| s[:id] }
    end
  end

  test "ignores unfinished sessions" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      build_session(finished: false, created_at: Time.zone.local(2026, 5, 13, 9, 0, 0))

      view = Student::FrequencyView.new(@student).to_h
      today_cell = view[:days].find { |d| d[:date] == Date.new(2026, 5, 13) }

      assert_empty today_cell[:sessions]
    end
  end

  test "ignores sessions from other students" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      other = @organization.students.create!(name: "Outro")
      build_session(student: other, finished: true, created_at: Time.zone.local(2026, 5, 13, 9, 0, 0))

      view = Student::FrequencyView.new(@student).to_h

      assert view[:days].all? { |d| d[:sessions].empty? }
    end
  end

  test "ignores sessions outside the 26-week window" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      window_start = Date.new(2025, 11, 17)
      before = finished_session_at(window_start.in_time_zone - 1.minute)

      view = Student::FrequencyView.new(@student).to_h

      assert view[:days].none? { |d| d[:sessions].any? { |s| s[:id] == before.id } }
    end
  end

  test "includes finished sessions at the window boundaries" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      start_session = finished_session_at(Time.zone.local(2025, 11, 17, 6, 0, 0))
      end_session   = finished_session_at(Time.zone.local(2026, 5, 17, 23, 30, 0))

      view = Student::FrequencyView.new(@student).to_h
      by_date = view[:days].index_by { |d| d[:date] }

      assert_includes by_date[Date.new(2025, 11, 17)][:sessions].map { |s| s[:id] }, start_session.id
      assert_includes by_date[Date.new(2026, 5, 17)][:sessions].map { |s| s[:id] }, end_session.id
    end
  end

  private
    def finished_session_at(time)
      build_session(finished: true, created_at: time)
    end

    def build_session(student: @student, finished:, created_at:)
      session = TrainingSession.create!(
        student: student,
        trainer: @trainer,
        workout_name_snapshot: "Treino A",
        workout_position_snapshot: 1,
        blocks_snapshot: [],
        progress: []
      )
      session.update_columns(
        created_at: created_at,
        finished_at: finished ? created_at + 1.hour : nil
      )
      session
    end
end
