require "test_helper"

# Focuses on the periodization-flow methods on Student. The base Student
# behaviour lives in test/models/student_test.rb.
class StudentPeriodizationTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
  end

  test "start_periodization! creates a new periodization with a generating version and repoints the student" do
    assert_nil @student.active_periodization_id

    version = @student.start_periodization!(trainer: @trainer)

    @student.reload
    assert_equal version.periodization_id, @student.active_periodization_id
    assert_equal "generating", version.status
    assert_equal @trainer, version.trainer
    assert_nil version.parent_version_id
  end

  test "Periodization#start_edit! with :workout creates a pending generating version pointing at the parent" do
    parent_version = @student.start_periodization!(trainer: @trainer)
    parent_version.fork_with!(
      scope: :create,
      patch: {
        body_md: "x",
        periodization_length_weeks: 8,
        workouts: [ { name: "A", blocks: [ { kind: "exercise", name: "X", prescription: "3x5" } ], position: 1 } ]
      },
      trainer: @trainer
    )
    parent_version.transition_to!(:completed)
    periodization = parent_version.periodization
    periodization.set_current_version!(parent_version)
    target = parent_version.workouts.first

    new_version = periodization.start_edit!(
      scope: :workout,
      trainer: @trainer,
      target_workout: target
    )

    assert_equal "generating", new_version.status
    assert_equal parent_version.id, new_version.parent_version_id
    assert_equal periodization.id, new_version.periodization_id
    assert_equal parent_version.id, periodization.reload.current_version_id, "current_version is unchanged until promotion"
  end

  test "Periodization#start_edit! with :periodization creates a pending generating version pointing at the parent (no target_workout required)" do
    parent_version = @student.start_periodization!(trainer: @trainer)
    parent_version.fork_with!(
      scope: :create,
      patch: { body_md: "x", periodization_length_weeks: 8, workouts: [ { name: "A", blocks: [ { kind: "exercise", name: "X", prescription: "3x5" } ], position: 1 } ] },
      trainer: @trainer
    )
    parent_version.transition_to!(:completed)
    periodization = parent_version.periodization
    periodization.set_current_version!(parent_version)

    new_version = periodization.start_edit!(scope: :periodization, trainer: @trainer)

    assert_equal "generating", new_version.status
    assert_equal parent_version.id, new_version.parent_version_id
    assert_equal periodization.id, new_version.periodization_id
    assert_equal parent_version.id, periodization.reload.current_version_id, "current_version is unchanged until promotion"
  end

  test "Periodization#start_edit! rejects unknown scopes and missing target_workout" do
    parent_version = @student.start_periodization!(trainer: @trainer)
    parent_version.fork_with!(
      scope: :create,
      patch: { body_md: "x", periodization_length_weeks: 8, workouts: [ { name: "A", blocks: [ { kind: "exercise", name: "X", prescription: "3x5" } ], position: 1 } ] },
      trainer: @trainer
    )
    parent_version.transition_to!(:completed)
    periodization = parent_version.periodization
    periodization.set_current_version!(parent_version)

    assert_raises(ArgumentError) do
      periodization.start_edit!(scope: :workout, trainer: @trainer, target_workout: nil)
    end

    assert_raises(ArgumentError) do
      periodization.start_edit!(scope: :bogus, trainer: @trainer, target_workout: parent_version.workouts.first)
    end
  end

  test "start_periodization! archives the prior active periodization in the same transaction" do
    first = @student.start_periodization!(trainer: @trainer)
    first_periodization = first.periodization
    assert_not first_periodization.archived?

    second = @student.start_periodization!(trainer: @trainer)

    assert first_periodization.reload.archived?
    assert_not second.periodization.reload.archived?
    assert_equal second.periodization_id, @student.reload.active_periodization_id
    assert_not_equal first.periodization_id, second.periodization_id
  end

  test "start_periodization_from_template! copies content into a completed, promoted version and repoints the student" do
    template = template_with_workouts

    periodization = @student.start_periodization_from_template!(template, trainer: @trainer)

    @student.reload
    assert_equal periodization.id, @student.active_periodization_id

    version = periodization.current_version
    assert_not_nil version, "the new periodization is promoted (current_version set)"
    assert_equal "completed", version.status
    assert_nil version.parent_version_id
    assert_equal @trainer, version.trainer

    assert_equal "## Plano base", version.body_md
    assert_equal 8, version.periodization_length_weeks
    workouts = version.workouts.order(:position).to_a
    assert_equal [ "A", "B" ], workouts.map(&:name)
    assert_equal [ 1, 2 ], workouts.map(&:position)
    assert_equal "Agachamento", workouts.first.blocks.first["name"]
    assert_equal "4x8", workouts.first.blocks.first["prescription"]
  end

  test "start_periodization_from_template! archives a pre-existing active periodization, preserving the invariant" do
    prior = @student.start_periodization!(trainer: @trainer)
    prior_periodization = prior.periodization
    assert_not prior_periodization.archived?

    cloned = @student.start_periodization_from_template!(template_with_workouts, trainer: @trainer)

    assert prior_periodization.reload.archived?
    assert_not cloned.reload.archived?
    assert_equal cloned.id, @student.reload.active_periodization_id
    assert_not_equal prior_periodization.id, cloned.id
  end

  test "start_periodization_from_template! works when the student had no active periodization" do
    assert_nil @student.active_periodization_id

    cloned = @student.start_periodization_from_template!(template_with_workouts, trainer: @trainer)

    assert_equal cloned.id, @student.reload.active_periodization_id
    assert_equal "completed", cloned.current_version.status
  end

  test "start_periodization_from_template! enqueues exercise linking when the cloned version completes" do
    template = template_with_workouts

    assert_enqueued_with(job: LinkExercisesJob) do
      @student.start_periodization_from_template!(template, trainer: @trainer)
    end
  end

  private
    def template_with_workouts
      source = @student.start_periodization!(trainer: @trainer)
      source.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano base",
          periodization_length_weeks: 8,
          workouts: [
            { name: "A", blocks: [ { "kind" => "exercise", "name" => "Agachamento", "prescription" => "4x8" } ], position: 1 },
            { name: "B", blocks: [ { "kind" => "exercise", "name" => "Supino", "prescription" => "4x8" } ], position: 2 }
          ]
        },
        trainer: @trainer
      )
      source.transition_to!(:completed)
      template = PeriodizationTemplate.create_from_version!(source, name: "Iniciante 3x")

      # Archive the helper source periodization so the student starts clean for
      # the test under exercise (the template is now an independent snapshot).
      source.periodization.archive!
      @student.update!(active_periodization: nil)

      template
    end
end
