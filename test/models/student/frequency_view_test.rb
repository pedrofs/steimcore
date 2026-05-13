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

  test "assigns palette slots chronologically by first-seen version in the window" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      v1 = build_periodization_version
      v2 = build_periodization_version
      v3 = build_periodization_version
      finished_session_at(Time.zone.local(2026, 1, 5, 10, 0, 0), periodization_version: v2)
      finished_session_at(Time.zone.local(2026, 2, 7, 10, 0, 0), periodization_version: v1)
      finished_session_at(Time.zone.local(2026, 3, 8, 10, 0, 0), periodization_version: v3)

      view = Student::FrequencyView.new(@student).to_h

      assert_equal [ v2.id, v1.id, v3.id ], view[:versions].map { |v| v[:id] }
      assert_equal [ 1, 2, 3 ], view[:versions].map { |v| v[:number] }
      assert_equal [ 0, 1, 2 ], view[:versions].map { |v| v[:palette_slot] }
    end
  end

  test "palette slot wraps after PALETTE_SIZE distinct versions" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      versions = Array.new(Student::FrequencyView::PALETTE_SIZE + 1) { build_periodization_version }
      versions.each_with_index do |version, i|
        finished_session_at(Time.zone.local(2026, 1, 1, 0, 0, 0) + i.weeks, periodization_version: version)
      end

      view = Student::FrequencyView.new(@student).to_h

      slots = view[:versions].map { |v| v[:palette_slot] }
      assert_equal [ 0, 1, 2, 3, 4, 0 ], slots
    end
  end

  test "session payload includes periodization_version_id and palette_slot matching its version" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      version_a = build_periodization_version
      version_b = build_periodization_version
      session_a = finished_session_at(Time.zone.local(2026, 1, 5, 10, 0, 0), periodization_version: version_a)
      session_b = finished_session_at(Time.zone.local(2026, 2, 7, 10, 0, 0), periodization_version: version_b)

      view = Student::FrequencyView.new(@student).to_h
      session_payloads = view[:days].flat_map { |d| d[:sessions] }.index_by { |s| s[:id] }

      assert_equal version_a.id, session_payloads[session_a.id][:periodization_version_id]
      assert_equal 0, session_payloads[session_a.id][:palette_slot]
      assert_equal version_b.id, session_payloads[session_b.id][:periodization_version_id]
      assert_equal 1, session_payloads[session_b.id][:palette_slot]
    end
  end

  test "session payload tolerates a null periodization_version_id" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      orphan = finished_session_at(Time.zone.local(2026, 2, 1, 10, 0, 0), periodization_version: nil)

      view = Student::FrequencyView.new(@student).to_h
      payload = view[:days].flat_map { |d| d[:sessions] }.find { |s| s[:id] == orphan.id }

      assert_nil payload[:periodization_version_id]
      assert_nil payload[:palette_slot]
      assert_empty view[:versions]
    end
  end

  test "version range_start and range_end are the first and last session dates in the window for that version" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      version = build_periodization_version
      finished_session_at(Time.zone.local(2026, 1, 5, 10, 0, 0), periodization_version: version)
      finished_session_at(Time.zone.local(2026, 2, 10, 10, 0, 0), periodization_version: version)
      finished_session_at(Time.zone.local(2026, 3, 12, 10, 0, 0), periodization_version: version)

      view = Student::FrequencyView.new(@student).to_h
      entry = view[:versions].first

      assert_equal Date.new(2026, 1, 5), entry[:range_start]
      assert_equal Date.new(2026, 3, 12), entry[:range_end]
    end
  end

  test "is_current is true only when the version is the current_version_id of an unarchived periodization" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      promoted = build_periodization_version
      promoted.periodization.set_current_version!(promoted)

      superseded = build_periodization_version
      # default current_version_id remains nil on its periodization

      archived_promoted = build_periodization_version
      archived_promoted.periodization.set_current_version!(archived_promoted)
      archived_promoted.periodization.update!(archived_at: Time.current)

      finished_session_at(Time.zone.local(2026, 1, 5, 10, 0, 0), periodization_version: promoted)
      finished_session_at(Time.zone.local(2026, 2, 10, 10, 0, 0), periodization_version: superseded)
      finished_session_at(Time.zone.local(2026, 3, 12, 10, 0, 0), periodization_version: archived_promoted)

      view = Student::FrequencyView.new(@student).to_h
      flags = view[:versions].index_by { |v| v[:id] }

      assert flags[promoted.id][:is_current]
      assert_not flags[superseded.id][:is_current]
      assert_not flags[archived_promoted.id][:is_current]
    end
  end

  test "versions include periodization_id" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      version = build_periodization_version
      finished_session_at(Time.zone.local(2026, 1, 5, 10, 0, 0), periodization_version: version)

      view = Student::FrequencyView.new(@student).to_h

      assert_equal version.periodization_id, view[:versions].first[:periodization_id]
    end
  end

  test "palette slot assignment is deterministic across reloads with the same data" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      v1 = build_periodization_version
      v2 = build_periodization_version
      finished_session_at(Time.zone.local(2026, 1, 5, 10, 0, 0), periodization_version: v1)
      finished_session_at(Time.zone.local(2026, 2, 7, 10, 0, 0), periodization_version: v2)

      first = Student::FrequencyView.new(@student).to_h
      second = Student::FrequencyView.new(@student).to_h

      assert_equal first[:versions].map { |v| [ v[:id], v[:palette_slot] ] },
                   second[:versions].map { |v| [ v[:id], v[:palette_slot] ] }
    end
  end

  private
    def finished_session_at(time, periodization_version: :auto)
      build_session(finished: true, created_at: time, periodization_version: periodization_version)
    end

    def build_session(student: @student, finished:, created_at:, periodization_version: :auto)
      version = periodization_version == :auto ? build_periodization_version : periodization_version
      session = TrainingSession.create!(
        student: student,
        trainer: @trainer,
        periodization_version: version,
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

    def build_periodization_version
      periodization = @student.periodizations.create!
      periodization.versions.create!(trainer: @trainer, status: "completed")
    end
end
