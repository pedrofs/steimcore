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

  test "create scope rejects unknown scopes" do
    assert_raises(ArgumentError) do
      @version.fork_with!(scope: :workout, patch: {}, trainer: @trainer, voice_recording: @recording)
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
end
