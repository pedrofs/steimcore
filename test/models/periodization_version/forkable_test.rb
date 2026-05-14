require "test_helper"

class PeriodizationVersion::ForkableTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    @periodization = @student.periodizations.create!
    @version = @periodization.versions.build(
      trainer: @trainer,
      parent_version: nil
    )
    @version.save!
  end

  test "create scope sets body_md and builds workouts in the given positions" do
    patch = {
      body_md: "## Plano\n\nMesociclo de hipertrofia.",
      workouts: [
        { name: "A", blocks: [ exercise("Agachamento", "4x8") ], position: 1 },
        { name: "B", blocks: [ exercise("Supino", "4x8") ],      position: 2 },
        { name: "C", blocks: [ exercise("Levantamento terra", "3x5") ], position: 3 }
      ]
    }

    @version.fork_with!(scope: :create, patch: patch, trainer: @trainer)

    @version.reload
    assert_equal "## Plano\n\nMesociclo de hipertrofia.", @version.body_md
    assert_equal 3, @version.workouts.count
    assert_equal %w[A B C], @version.workouts.order(:position).pluck(:name)
    assert_equal [ 1, 2, 3 ], @version.workouts.order(:position).pluck(:position)
    assert_equal "Agachamento", @version.workouts.find_by(name: "A").blocks.first["name"]
  end

  test "rejects unknown scopes" do
    assert_raises(ArgumentError) do
      @version.fork_with!(scope: :bogus, patch: {}, trainer: @trainer)
    end
  end

  test "create scope rejects when parent_version is present" do
    parent = @version
    child = @periodization.versions.build(
      trainer: @trainer,
      parent_version: parent
    )
    child.save!

    assert_raises(ArgumentError) do
      child.fork_with!(scope: :create, patch: { body_md: "x", workouts: [] }, trainer: @trainer)
    end
  end

  test "create scope accepts string-keyed patches (RubyLLM JSON output)" do
    patch = {
      "body_md" => "Body",
      "workouts" => [
        {
          "name" => "A",
          "blocks" => [ { "kind" => "exercise", "name" => "Supino", "prescription" => "3x8" } ],
          "position" => 1
        }
      ]
    }

    @version.fork_with!(scope: :create, patch: patch, trainer: @trainer)

    @version.reload
    assert_equal "Body", @version.body_md
    assert_equal "A", @version.workouts.first.name
    assert_equal "Supino", @version.workouts.first.blocks.first["name"]
  end

  test "create scope persists each of the three block kinds" do
    patch = {
      body_md: "## Plano",
      workouts: [
        {
          name: "A",
          position: 1,
          blocks: [
            { kind: "freeform", text_md: "Aquecimento 5 min" },
            { kind: "exercise", name: "Agachamento", prescription: "5x5", rest_s: 120, notes: "tempo 3-0-1" },
            {
              kind: "group",
              label: "Superset",
              rounds: 3,
              items: [
                { name: "Rosca", prescription: "10 reps" },
                { name: "Tríceps", prescription: "10 reps" }
              ]
            }
          ]
        }
      ]
    }

    @version.fork_with!(scope: :create, patch: patch, trainer: @trainer)

    blocks = @version.reload.workouts.first.blocks
    assert_equal %w[freeform exercise group], blocks.map { |b| b["kind"] }
    assert_equal 3, blocks.last["rounds"]
    assert_equal 2, blocks.last["items"].size
  end

  # --- :workout scope ---

  test "workout scope replaces only the targeted workout, copies the rest byte-identical, and copies body_md from parent" do
    setup_parent_with_three_workouts!
    target = @parent_version.workouts.find_by(position: 2)

    new_version = build_child_version

    patch = {
      workout: {
        name: "B'",
        blocks: [ exercise("Supino inclinado", "4x10") ]
      }
    }

    new_version.fork_with!(
      scope: :workout,
      patch: patch,
      trainer: @trainer,
      target_workout: target
    )

    new_version.reload
    assert_equal @parent_version.body_md, new_version.body_md, "body_md must be copied unchanged"

    by_position = new_version.workouts.order(:position).index_by(&:position)
    assert_equal 3, by_position.size
    assert_equal [ 1, 2, 3 ], by_position.keys

    assert_equal "A", by_position[1].name
    assert_equal "Agachamento", by_position[1].blocks.first["name"]

    assert_equal "B'", by_position[2].name
    assert_equal "Supino inclinado", by_position[2].blocks.first["name"]

    assert_equal "C", by_position[3].name
    assert_equal "Levantamento terra", by_position[3].blocks.first["name"]
  end

  test "workout scope sets parent_version_id and trainer on the new version" do
    setup_parent_with_three_workouts!
    target = @parent_version.workouts.find_by(position: 1)
    other_trainer = users(:two)

    new_version = build_child_version(trainer: other_trainer)

    new_version.fork_with!(
      scope: :workout,
      patch: { workout: { name: "A2", blocks: [ exercise("Novo", "3x8") ] } },
      trainer: other_trainer,
      target_workout: target
    )

    new_version.reload
    assert_equal @parent_version.id, new_version.parent_version_id
    assert_equal other_trainer.id, new_version.trainer_id
  end

  test "workout scope requires target_workout" do
    setup_parent_with_three_workouts!
    new_version = build_child_version

    assert_raises(ArgumentError) do
      new_version.fork_with!(
        scope: :workout,
        patch: { workout: { name: "x", blocks: [] } },
        trainer: @trainer,
        target_workout: nil
      )
    end
  end

  test "workout scope requires parent_version" do
    @version.fork_with!(
      scope: :create,
      patch: { body_md: "x", workouts: [ { name: "A", blocks: [ exercise("Supino", "3x8") ], position: 1 } ] },
      trainer: @trainer
    )
    target = @version.reload.workouts.first

    orphan = @periodization.versions.build(
      trainer: @trainer,
      parent_version: nil
    )
    orphan.save!

    assert_raises(ArgumentError) do
      orphan.fork_with!(
        scope: :workout,
        patch: { workout: { name: "x", blocks: [] } },
        trainer: @trainer,
        target_workout: target
      )
    end
  end

  test "workout scope accepts string-keyed patches" do
    setup_parent_with_three_workouts!
    target = @parent_version.workouts.find_by(position: 3)
    new_version = build_child_version

    new_version.fork_with!(
      scope: :workout,
      patch: {
        "workout" => {
          "name" => "C2",
          "blocks" => [ { "kind" => "exercise", "name" => "Foo", "prescription" => "3x5" } ]
        }
      },
      trainer: @trainer,
      target_workout: target
    )

    new_version.reload
    workout = new_version.workouts.find_by(position: 3)
    assert_equal "C2", workout.name
    assert_equal "Foo", workout.blocks.first["name"]
  end

  # --- :clone scope ---

  test "clone scope copies body_md and workouts byte-identical from parent and is born :completed" do
    setup_parent_with_three_workouts!

    new_version = build_child_version

    new_version.fork_with!(scope: :clone, patch: nil, trainer: @trainer)

    new_version.reload
    assert_equal @parent_version.body_md, new_version.body_md

    by_position = new_version.workouts.order(:position).index_by(&:position)
    assert_equal [ 1, 2, 3 ], by_position.keys
    assert_equal "A", by_position[1].name
    assert_equal "B", by_position[2].name
    assert_equal "C", by_position[3].name

    @parent_version.workouts.order(:position).each do |parent_w|
      child_w = by_position[parent_w.position]
      assert_equal parent_w.name, child_w.name
      assert_equal parent_w.blocks, child_w.blocks
    end
  end

  test "clone scope sets parent_version_id, trainer_id, and status :completed" do
    setup_parent_with_three_workouts!
    other_trainer = users(:two)
    new_version = build_child_version(trainer: other_trainer)

    new_version.fork_with!(scope: :clone, patch: nil, trainer: other_trainer)

    new_version.reload
    assert_equal @parent_version.id, new_version.parent_version_id
    assert_equal other_trainer.id, new_version.trainer_id
    assert_equal "completed", new_version.status
  end

  test "clone scope raises ArgumentError if a non-nil patch is supplied" do
    setup_parent_with_three_workouts!
    new_version = build_child_version

    assert_raises(ArgumentError) do
      new_version.fork_with!(scope: :clone, patch: { body_md: "x" }, trainer: @trainer)
    end
  end

  test "clone scope requires parent_version" do
    orphan = @periodization.versions.build(
      trainer: @trainer,
      parent_version: nil
    )
    orphan.save!

    assert_raises(ArgumentError) do
      orphan.fork_with!(scope: :clone, patch: nil, trainer: @trainer)
    end
  end

  # --- :periodization scope ---

  test "periodization scope replaces body_md and the entire workouts array; previous workouts are not retained" do
    setup_parent_with_three_workouts!

    new_version = build_child_version

    patch = {
      body_md: "## Novo plano\n\nFoco em força.",
      workouts: [
        { name: "Push", blocks: [ exercise("Supino", "5x5") ], position: 1 },
        { name: "Pull", blocks: [ exercise("Remada", "5x5") ], position: 2 }
      ]
    }

    new_version.fork_with!(scope: :periodization, patch: patch, trainer: @trainer)

    new_version.reload
    assert_equal "## Novo plano\n\nFoco em força.", new_version.body_md

    workouts = new_version.workouts.order(:position)
    assert_equal 2, workouts.count, "previous workouts must NOT be carried forward"
    assert_equal %w[Push Pull], workouts.pluck(:name)
    assert_equal [ 1, 2 ], workouts.pluck(:position)

    assert_equal 3, @parent_version.reload.workouts.count, "parent workouts remain intact"
  end

  test "periodization scope sets parent_version_id and trainer on the new version" do
    setup_parent_with_three_workouts!
    other_trainer = users(:two)

    new_version = build_child_version(trainer: other_trainer)

    new_version.fork_with!(
      scope: :periodization,
      patch: {
        body_md: "x",
        workouts: [ { name: "A", blocks: [ exercise("Supino", "3x8") ], position: 1 } ]
      },
      trainer: other_trainer
    )

    new_version.reload
    assert_equal @parent_version.id, new_version.parent_version_id
    assert_equal other_trainer.id, new_version.trainer_id
  end

  test "periodization scope requires parent_version" do
    orphan = @periodization.versions.build(
      trainer: @trainer,
      parent_version: nil
    )
    orphan.save!

    assert_raises(ArgumentError) do
      orphan.fork_with!(
        scope: :periodization,
        patch: { body_md: "x", workouts: [] },
        trainer: @trainer
      )
    end
  end

  test "periodization scope accepts string-keyed patches" do
    setup_parent_with_three_workouts!
    new_version = build_child_version

    new_version.fork_with!(
      scope: :periodization,
      patch: {
        "body_md" => "Body",
        "workouts" => [
          {
            "name" => "X",
            "blocks" => [ { "kind" => "exercise", "name" => "Foo", "prescription" => "3x5" } ],
            "position" => 1
          }
        ]
      },
      trainer: @trainer
    )

    new_version.reload
    assert_equal "Body", new_version.body_md
    assert_equal 1, new_version.workouts.count
    assert_equal "X", new_version.workouts.first.name
  end

  # --- apply_patch!(:workout) ---

  test "apply_patch! :workout mutates the receiver: target workout replaced; other workouts byte-identical" do
    setup_editable_draft_with_three_workouts!
    target = @draft.workouts.find_by(position: 2)

    before_count = PeriodizationVersion.count
    other_workouts_before = @draft.workouts.where.not(position: 2).order(:position).map { |w| [ w.name, w.blocks ] }

    @draft.apply_patch!(
      scope: :workout,
      patch: { workout: { name: "B'", blocks: [ exercise("Supino inclinado", "4x10") ] } },
      trainer: @trainer,
      target_workout: target
    )

    assert_equal before_count, PeriodizationVersion.count, "no new PeriodizationVersion row should be created"

    @draft.reload
    by_position = @draft.workouts.order(:position).index_by(&:position)
    assert_equal "B'", by_position[2].name
    assert_equal "Supino inclinado", by_position[2].blocks.first["name"]

    other_workouts_after = @draft.workouts.where.not(position: 2).order(:position).map { |w| [ w.name, w.blocks ] }
    assert_equal other_workouts_before, other_workouts_after, "other workouts must remain byte-identical"
  end

  test "apply_patch! :workout accepts string-keyed patches" do
    setup_editable_draft_with_three_workouts!
    target = @draft.workouts.find_by(position: 1)

    @draft.apply_patch!(
      scope: :workout,
      patch: {
        "workout" => {
          "name" => "A2",
          "blocks" => [ { "kind" => "exercise", "name" => "Novo", "prescription" => "3x5" } ]
        }
      },
      trainer: @trainer,
      target_workout: target
    )

    @draft.reload
    workout = @draft.workouts.find_by(position: 1)
    assert_equal "A2", workout.name
    assert_equal "Novo", workout.blocks.first["name"]
  end

  test "apply_patch! :workout requires target_workout" do
    setup_editable_draft_with_three_workouts!

    assert_raises(ArgumentError) do
      @draft.apply_patch!(
        scope: :workout,
        patch: { workout: { name: "x", blocks: [] } },
        trainer: @trainer,
        target_workout: nil
      )
    end
  end

  # --- apply_patch!(:periodization) ---

  test "apply_patch! :periodization mutates the receiver: body_md and full workouts list replaced" do
    setup_editable_draft_with_three_workouts!

    before_count = PeriodizationVersion.count

    @draft.apply_patch!(
      scope: :periodization,
      patch: {
        body_md: "## Plano novo\n\nFoco em força.",
        workouts: [
          { name: "Push", blocks: [ exercise("Supino", "5x5") ], position: 1 },
          { name: "Pull", blocks: [ exercise("Remada", "5x5") ], position: 2 }
        ]
      },
      trainer: @trainer
    )

    assert_equal before_count, PeriodizationVersion.count, "no new PeriodizationVersion row should be created"

    @draft.reload
    assert_equal "## Plano novo\n\nFoco em força.", @draft.body_md
    assert_equal %w[Push Pull], @draft.workouts.order(:position).pluck(:name)
    assert_equal [ 1, 2 ], @draft.workouts.order(:position).pluck(:position)
  end

  test "apply_patch! :periodization accepts string-keyed patches" do
    setup_editable_draft_with_three_workouts!

    @draft.apply_patch!(
      scope: :periodization,
      patch: {
        "body_md" => "Body",
        "workouts" => [
          { "name" => "X", "blocks" => [ { "kind" => "exercise", "name" => "Foo", "prescription" => "3x5" } ], "position" => 1 }
        ]
      },
      trainer: @trainer
    )

    @draft.reload
    assert_equal "Body", @draft.body_md
    assert_equal "X", @draft.workouts.first.name
  end

  # --- apply_patch! invalid scopes ---

  test "apply_patch! :clone raises ArgumentError" do
    setup_editable_draft_with_three_workouts!

    assert_raises(ArgumentError) do
      @draft.apply_patch!(scope: :clone, patch: nil, trainer: @trainer)
    end
  end

  test "apply_patch! :create raises ArgumentError" do
    setup_editable_draft_with_three_workouts!

    assert_raises(ArgumentError) do
      @draft.apply_patch!(scope: :create, patch: { body_md: "x", workouts: [] }, trainer: @trainer)
    end
  end

  test "apply_patch! rejects unknown scopes" do
    setup_editable_draft_with_three_workouts!

    assert_raises(ArgumentError) do
      @draft.apply_patch!(scope: :bogus, patch: {}, trainer: @trainer)
    end
  end

  private
    def exercise(name, prescription)
      { kind: "exercise", name: name, prescription: prescription }
    end

    def setup_parent_with_three_workouts!
      @version.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano\n\nMesociclo base.",
          workouts: [
            { name: "A", blocks: [ exercise("Agachamento", "4x8") ], position: 1 },
            { name: "B", blocks: [ exercise("Supino", "4x8") ], position: 2 },
            { name: "C", blocks: [ exercise("Levantamento terra", "3x5") ], position: 3 }
          ]
        },
        trainer: @trainer
      )
      @parent_version = @version.reload
      @periodization.update!(current_version: @parent_version)
    end

    def build_child_version(trainer: @trainer)
      child = @periodization.versions.build(
        trainer: trainer,
        parent_version: @parent_version
      )
      child.save!
      child
    end

    def setup_editable_draft_with_three_workouts!
      setup_parent_with_three_workouts!
      @draft = build_child_version
      @draft.fork_with!(scope: :clone, patch: nil, trainer: @trainer)
      @draft.reload
    end
end
