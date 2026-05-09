require "test_helper"

class PeriodizationVersion::ForkableTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    @recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @trainer,
      kind: "periodization_create"
    )
    @periodization = @student.periodizations.create!
    @version = @periodization.versions.build(
      trainer: @trainer,
      voice_recording: @recording,
      parent_version: nil
    )
    @version.save!
  end

  test "create scope sets body_md and builds workouts in the given positions" do
    patch = {
      body_md: "## Plano\n\nMesociclo de hipertrofia.",
      workouts: [
        { name: "A", content_md: "Agachamento 4x8", position: 1 },
        { name: "B", content_md: "Supino 4x8",      position: 2 },
        { name: "C", content_md: "Levantamento terra 3x5", position: 3 }
      ]
    }

    @version.fork_with!(scope: :create, patch: patch, trainer: @trainer, voice_recording: @recording)

    @version.reload
    assert_equal "## Plano\n\nMesociclo de hipertrofia.", @version.body_md
    assert_equal 3, @version.workouts.count
    assert_equal %w[A B C], @version.workouts.order(:position).pluck(:name)
    assert_equal [ 1, 2, 3 ], @version.workouts.order(:position).pluck(:position)
    assert_match(/Agachamento/, @version.workouts.find_by(name: "A").content_md)
  end

  test "rejects unknown scopes" do
    assert_raises(ArgumentError) do
      @version.fork_with!(scope: :bogus, patch: {}, trainer: @trainer, voice_recording: @recording)
    end
  end

  test "create scope rejects when parent_version is present" do
    parent = @version
    child = @periodization.versions.build(
      trainer: @trainer,
      voice_recording: @recording,
      parent_version: parent
    )
    child.save!

    assert_raises(ArgumentError) do
      child.fork_with!(scope: :create, patch: { body_md: "x", workouts: [] }, trainer: @trainer, voice_recording: @recording)
    end
  end

  test "create scope accepts string-keyed patches (RubyLLM JSON output)" do
    patch = {
      "body_md" => "Body",
      "workouts" => [ { "name" => "A", "content_md" => "x", "position" => 1 } ]
    }

    @version.fork_with!(scope: :create, patch: patch, trainer: @trainer, voice_recording: @recording)

    @version.reload
    assert_equal "Body", @version.body_md
    assert_equal "A", @version.workouts.first.name
  end

  # --- :workout scope ---

  test "workout scope replaces only the targeted workout, copies the rest byte-identical, and copies body_md from parent" do
    setup_parent_with_three_workouts!
    target = @parent_version.workouts.find_by(position: 2)

    edit_recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @trainer,
      kind: "periodization_edit_workout",
      target_workout: target
    )

    new_version = build_child_version(voice_recording: edit_recording)

    patch = { workout: { name: "B'", content_md: "Supino inclinado 4x10" } }

    new_version.fork_with!(
      scope: :workout,
      patch: patch,
      trainer: @trainer,
      voice_recording: edit_recording,
      target_workout: target
    )

    new_version.reload
    assert_equal @parent_version.body_md, new_version.body_md, "body_md must be copied unchanged"

    by_position = new_version.workouts.order(:position).index_by(&:position)
    assert_equal 3, by_position.size
    assert_equal [ 1, 2, 3 ], by_position.keys

    assert_equal "A", by_position[1].name
    assert_equal "Agachamento 4x8", by_position[1].content_md

    assert_equal "B'", by_position[2].name
    assert_equal "Supino inclinado 4x10", by_position[2].content_md

    assert_equal "C", by_position[3].name
    assert_equal "Levantamento terra 3x5", by_position[3].content_md
  end

  test "workout scope sets parent_version_id, trainer, and voice_recording on the new version" do
    setup_parent_with_three_workouts!
    target = @parent_version.workouts.find_by(position: 1)
    other_trainer = users(:two)
    edit_recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: other_trainer,
      kind: "periodization_edit_workout",
      target_workout: target
    )

    new_version = build_child_version(voice_recording: edit_recording, trainer: other_trainer)

    new_version.fork_with!(
      scope: :workout,
      patch: { workout: { name: "A2", content_md: "novo conteúdo" } },
      trainer: other_trainer,
      voice_recording: edit_recording,
      target_workout: target
    )

    new_version.reload
    assert_equal @parent_version.id, new_version.parent_version_id
    assert_equal other_trainer.id, new_version.trainer_id
    assert_equal edit_recording.id, new_version.voice_recording_id
  end

  test "workout scope requires target_workout" do
    setup_parent_with_three_workouts!
    new_version = build_child_version

    assert_raises(ArgumentError) do
      new_version.fork_with!(
        scope: :workout,
        patch: { workout: { name: "x", content_md: "y" } },
        trainer: @trainer,
        voice_recording: nil,
        target_workout: nil
      )
    end
  end

  test "workout scope requires parent_version" do
    @version.fork_with!(scope: :create, patch: { body_md: "x", workouts: [ { name: "A", content_md: "y", position: 1 } ] }, trainer: @trainer, voice_recording: @recording)
    target = @version.reload.workouts.first

    orphan = @periodization.versions.build(
      trainer: @trainer,
      voice_recording: nil,
      parent_version: nil
    )
    orphan.save!

    assert_raises(ArgumentError) do
      orphan.fork_with!(
        scope: :workout,
        patch: { workout: { name: "x", content_md: "y" } },
        trainer: @trainer,
        voice_recording: nil,
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
      patch: { "workout" => { "name" => "C2", "content_md" => "x" } },
      trainer: @trainer,
      voice_recording: nil,
      target_workout: target
    )

    new_version.reload
    workout = new_version.workouts.find_by(position: 3)
    assert_equal "C2", workout.name
    assert_equal "x", workout.content_md
  end

  private
    def setup_parent_with_three_workouts!
      @version.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano\n\nMesociclo base.",
          workouts: [
            { name: "A", content_md: "Agachamento 4x8", position: 1 },
            { name: "B", content_md: "Supino 4x8", position: 2 },
            { name: "C", content_md: "Levantamento terra 3x5", position: 3 }
          ]
        },
        trainer: @trainer,
        voice_recording: @recording
      )
      @parent_version = @version.reload
      @periodization.update!(current_version: @parent_version)
    end

    def build_child_version(voice_recording: nil, trainer: @trainer)
      child = @periodization.versions.build(
        trainer: trainer,
        voice_recording: voice_recording,
        parent_version: @parent_version
      )
      child.save!
      child
    end
end
