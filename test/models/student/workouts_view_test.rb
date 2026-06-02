require "test_helper"

class Student::WorkoutsViewTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
    @trainer = users(:one)
  end

  test "lists the current version's workouts in prescribed position order" do
    build_active_plan!

    workouts = Student::WorkoutsView.new(@student.reload).to_h[:workouts]

    assert_equal [ "Treino A", "Treino B" ], workouts.map { |w| w[:name] }
    assert_equal [ 1, 2 ], workouts.map { |w| w[:position] }
  end

  test "each workout payload carries id, name, position and blocks" do
    plan = build_active_plan!
    treino_a = plan[:version].workouts.find_by(position: 1)

    payload = Student::WorkoutsView.new(@student.reload).to_h[:workouts].first

    assert_equal treino_a.id, payload[:id]
    assert_equal "Treino A", payload[:name]
    assert_equal 1, payload[:position]
    assert_equal [ { "kind" => "exercise", "name" => "Supino", "prescription" => "4x10" } ], payload[:blocks]
  end

  test "returns an empty list when the student has no active periodization" do
    assert_equal [], Student::WorkoutsView.new(@student).to_h[:workouts]
  end

  test "returns an empty list when the active periodization has no promoted current version" do
    periodization = @student.periodizations.create!
    periodization.versions.create!(trainer: @trainer, status: "generating")
    @student.update!(active_periodization: periodization)

    assert_equal [], Student::WorkoutsView.new(@student.reload).to_h[:workouts]
  end

  test "returns an empty list when the current version has zero workouts" do
    periodization = @student.periodizations.create!
    version = periodization.versions.create!(trainer: @trainer, status: "completed", periodization_length_weeks: 8)
    periodization.set_current_version!(version)
    @student.update!(active_periodization: periodization)

    assert_equal [], Student::WorkoutsView.new(@student.reload).to_h[:workouts]
  end

  test "shows only the promoted current version, not superseded or draft versions" do
    plan = build_active_plan!
    # A newer draft forked off the current version carries different workouts but
    # is not promoted; the student must not see it.
    draft = plan[:periodization].versions.create!(
      trainer: @trainer, status: "completed", periodization_length_weeks: 8, parent_version: plan[:version]
    )
    draft.workouts.create!(name: "Treino Secreto", position: 1, blocks: [])

    workouts = Student::WorkoutsView.new(@student.reload).to_h[:workouts]

    assert_equal [ "Treino A", "Treino B" ], workouts.map { |w| w[:name] }
    assert_not_includes workouts.map { |w| w[:name] }, "Treino Secreto"
  end

  private
    def build_active_plan!
      periodization = @student.periodizations.create!
      version = periodization.versions.create!(trainer: @trainer, status: "completed", periodization_length_weeks: 8)
      version.workouts.create!(name: "Treino A", position: 1, blocks: [
        { "kind" => "exercise", "name" => "Supino", "prescription" => "4x10" }
      ])
      version.workouts.create!(name: "Treino B", position: 2, blocks: [
        { "kind" => "exercise", "name" => "Agachamento", "prescription" => "4x8" }
      ])
      periodization.set_current_version!(version)
      @student.update!(active_periodization: periodization)
      { periodization: periodization, version: version }
    end
end
