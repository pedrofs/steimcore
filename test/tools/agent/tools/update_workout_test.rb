require "test_helper"

class Agent::Tools::UpdateWorkoutTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    @tool = Agent::Tools::UpdateWorkout.new(student: @student, trainer: @trainer)
  end

  test "mutates the target workout in place when current_version is editable" do
    version = seed_draft_periodization_with_three_workouts!
    target = version.workouts.find_by(position: 2)

    result = @tool.execute(
      workout_id: target.id,
      name: "B'",
      blocks: [ { "kind" => "exercise", "name" => "Supino inclinado", "prescription" => "4x10" } ],
      summary_md: "Trocou supino reto por inclinado."
    )

    target.reload
    assert_equal "B'", target.name
    assert_equal "Supino inclinado", target.blocks.first["name"]
    assert_equal version.id, result[:version_id]
    assert_equal target.id, result[:workout_id]
    assert_equal "B'", result[:workout_name]
    assert_equal 1, @student.active_periodization.versions.count
  end

  test "forks a new version when current_version is read-only" do
    version = seed_draft_periodization_with_three_workouts!
    version.periodization.set_current_version!(version)
    target = version.workouts.find_by(position: 1)

    result = @tool.execute(
      workout_id: target.id,
      name: "A v2",
      blocks: [ { "kind" => "exercise", "name" => "Agachamento frontal", "prescription" => "5x5" } ],
      summary_md: "Frontal no lugar do back-squat."
    )

    assert_equal 2, @student.active_periodization.versions.reload.count
    new_version = PeriodizationVersion.find(result[:version_id])
    assert_equal version.id, new_version.parent_version_id
    assert_equal 3, new_version.workouts.count, "other workouts must be carried forward byte-identical"
    new_a = new_version.workouts.find_by(position: 1)
    assert_equal "A v2", new_a.name
    assert_equal "Agachamento frontal", new_a.blocks.first["name"]
    assert_equal new_a.id, result[:workout_id]
  end

  test "soft-errors when the workout id does not belong to the current_version" do
    version = seed_draft_periodization_with_three_workouts!
    other_periodization = @student.periodizations.create!
    other_version = other_periodization.versions.create!(trainer: @trainer, parent_version: nil)
    foreign = other_version.workouts.create!(name: "Estrangeiro", position: 1, blocks: [ { kind: "exercise", name: "X", prescription: "3x5" } ])

    result = @tool.execute(
      workout_id: foreign.id,
      name: "Não",
      blocks: [ { "kind" => "exercise", "name" => "Supino", "prescription" => "3x5" } ],
      summary_md: "x"
    )

    assert_match(/treino não encontrado/i, result[:error])
    version.reload
    assert_equal "B", version.workouts.find_by(position: 2).name, "draft must be untouched"
  end

  test "soft-errors on block schema violations" do
    version = seed_draft_periodization_with_three_workouts!
    target = version.workouts.find_by(position: 1)

    result = @tool.execute(
      workout_id: target.id,
      name: "A",
      blocks: [ { "kind" => "exercise", "name" => "Agachamento" } ],
      summary_md: "x"
    )

    assert_match(/prescription/i, result[:error])
    target.reload
    assert_equal "Agachamento", target.blocks.first["name"]
  end

  test "soft-errors when no active periodization exists" do
    assert_nil @student.active_periodization

    result = @tool.execute(
      workout_id: SecureRandom.uuid,
      name: "qualquer",
      blocks: [ { "kind" => "exercise", "name" => "Supino", "prescription" => "3x5" } ],
      summary_md: "x"
    )

    assert_match(/não tem periodização ativa/i, result[:error])
  end

  private
    def seed_draft_periodization_with_three_workouts!
      version = @student.start_periodization!(trainer: @trainer)
      version.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano base",
          workouts: [
            { name: "A", position: 1, blocks: [ { kind: "exercise", name: "Agachamento", prescription: "4x8" } ] },
            { name: "B", position: 2, blocks: [ { kind: "exercise", name: "Supino", prescription: "4x8" } ] },
            { name: "C", position: 3, blocks: [ { kind: "exercise", name: "Levantamento terra", prescription: "3x5" } ] }
          ]
        },
        trainer: @trainer
      )
      version.complete!
      version.reload
    end
end
