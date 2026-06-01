require "test_helper"

class Student::DashboardViewTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
  end

  test "first_name is the first token of the student name" do
    assert_equal "Alice", Student::DashboardView.new(@student).to_h[:first_name]
  end

  test "calendar window is 5 week-aligned weeks (35 days) ending this week" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      days = Student::DashboardView.new(@student).to_h[:calendar][:days]

      assert_equal 35, days.length
      assert_equal Date.new(2026, 4, 13).iso8601, days.first[:date]
      assert_equal Date.new(2026, 5, 17).iso8601, days.last[:date]
    end
  end

  test "calendar marks days with a finished session as trained and flags future days" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      finished_session_at(Time.zone.local(2026, 5, 11, 9, 0, 0))

      days = Student::DashboardView.new(@student).to_h[:calendar][:days].index_by { |d| d[:date] }

      assert days[Date.new(2026, 5, 11).iso8601][:trained]
      assert_not days[Date.new(2026, 5, 12).iso8601][:trained]
      assert_not days[Date.new(2026, 5, 11).iso8601][:is_future]
      assert days[Date.new(2026, 5, 15).iso8601][:is_future]
    end
  end

  test "trained days carry a session summary with the workout name and flattened exercises" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      build_session(finished: true, created_at: Time.zone.local(2026, 5, 11, 9, 0, 0),
                    workout_name: "Treino B", blocks: [
                      { "kind" => "exercise", "name" => "Agachamento", "prescription" => "4x8" },
                      { "kind" => "group", "label" => "Circuito", "items" => [
                        { "name" => "Flexão", "prescription" => "3x12" },
                        { "name" => "Prancha", "prescription" => "60s" }
                      ] },
                      { "kind" => "freeform", "text_md" => "Alongar bem" }
                    ])

      days = Student::DashboardView.new(@student).to_h[:calendar][:days].index_by { |d| d[:date] }
      trained = days[Date.new(2026, 5, 11).iso8601]

      assert_equal 1, trained[:sessions].length
      summary = trained[:sessions].first
      assert_equal "Treino B", summary[:workout_name]
      assert_equal [ "Agachamento", "Flexão", "Prancha" ], summary[:exercises].map { |e| e[:name] }
      assert_equal "4x8", summary[:exercises].first[:detail]
    end
  end

  test "untrained days carry an empty sessions array" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      days = Student::DashboardView.new(@student).to_h[:calendar][:days]

      assert days.all? { |d| d[:sessions] == [] }
    end
  end

  test "trained_today and today_workout_name reflect a finished session created today" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      build_session(finished: true, created_at: Time.zone.local(2026, 5, 13, 8, 0, 0), workout_name: "Treino C")

      view = Student::DashboardView.new(@student).to_h

      assert view[:trained_today]
      assert_equal "Treino C", view[:today_workout_name]
    end
  end

  test "trained_today is false and today_workout_name nil without a session today" do
    travel_to Time.zone.local(2026, 5, 13, 10, 0, 0) do
      view = Student::DashboardView.new(@student).to_h

      assert_not view[:trained_today]
      assert_nil view[:today_workout_name]
    end
  end

  test "next_workout previews the upcoming workout, flattening groups and skipping freeform" do
    plan = build_active_plan!
    # Finishing position 1 makes Treino B (position 2) the next workout.
    build_session(finished: true, created_at: Time.zone.local(2026, 5, 12, 8, 0, 0),
                  workout_name: "Treino A", position: 1, version: plan[:version])

    next_workout = Student::DashboardView.new(@student.reload).to_h[:next_workout]

    assert_equal "Treino B", next_workout[:name]
    assert_equal 2, next_workout[:position]
    assert_equal 3, next_workout[:total_exercises] # 1 exercise + 2 group items; freeform skipped
    assert_equal [ "Agachamento", "Flexão", "Prancha" ], next_workout[:preview].map { |e| e[:name] }
    assert_equal "4x8", next_workout[:preview].first[:detail]
  end

  test "progress is computed from the active periodization when applicable" do
    plan = build_active_plan! # length 8 weeks, weekly_frequency nil -> effective 5 -> target 40
    2.times { build_session(finished: true, created_at: Time.zone.local(2026, 5, 12, 8, 0, 0), version: plan[:version]) }

    progress = Student::DashboardView.new(@student.reload).to_h[:progress]

    assert_equal 2, progress[:sessions_done]
    assert_equal 40, progress[:target]
    assert_equal 38, progress[:sessions_remaining]
    assert_equal 5, progress[:percent]
    assert_equal 8, progress[:length_weeks]
  end

  test "next_workout and progress are nil without an active periodization" do
    view = Student::DashboardView.new(@student).to_h

    assert_nil view[:next_workout]
    assert_nil view[:progress]
  end

  private
    def finished_session_at(time, **opts)
      build_session(finished: true, created_at: time, **opts)
    end

    def build_session(finished:, created_at:, workout_name: "Treino A", position: 1, version: :auto, blocks: [], student: @student)
      resolved = version == :auto ? build_version : version
      session = TrainingSession.create!(
        student: student,
        trainer: @trainer,
        periodization_version: resolved,
        workout_name_snapshot: workout_name,
        workout_position_snapshot: position,
        blocks_snapshot: blocks,
        progress: []
      )
      session.update_columns(created_at: created_at, finished_at: finished ? created_at + 1.hour : nil)
      session
    end

    def build_version
      periodization = @student.periodizations.create!
      periodization.versions.create!(trainer: @trainer, status: "completed", periodization_length_weeks: 8)
    end

    def build_active_plan!
      periodization = @student.periodizations.create!
      version = periodization.versions.create!(trainer: @trainer, status: "completed", periodization_length_weeks: 8)
      version.workouts.create!(name: "Treino A", position: 1, blocks: [
        { "kind" => "exercise", "name" => "Supino", "prescription" => "4x10" }
      ])
      version.workouts.create!(name: "Treino B", position: 2, blocks: [
        { "kind" => "exercise", "name" => "Agachamento", "prescription" => "4x8" },
        { "kind" => "group", "label" => "Circuito", "items" => [
          { "name" => "Flexão", "prescription" => "3x12" },
          { "name" => "Prancha", "prescription" => "60s" }
        ] },
        { "kind" => "freeform", "text_md" => "Alongar bem" }
      ])
      periodization.set_current_version!(version)
      @student.update!(active_periodization: periodization)
      { periodization: periodization, version: version }
    end
end
