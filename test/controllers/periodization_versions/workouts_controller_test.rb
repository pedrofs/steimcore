require "test_helper"

class PeriodizationVersions::WorkoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @user,
      kind: "periodization_create"
    )
    @version = @student.start_periodization!(trainer: @user, voice_recording: @recording)
    @version.fork_with!(
      scope: :create,
      patch: {
        body_md: "## Plano",
        workouts: [
          { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 },
          { name: "B", blocks: [ exercise_block("Supino", "4x8") ], position: 2 }
        ]
      },
      trainer: @user,
      voice_recording: @recording
    )
    @version.transition_to!(:completed)
    @workout = @version.workouts.order(:position).first
  end

  test "update replaces the workout's blocks" do
    sign_in_as(@user)
    new_blocks = [
      exercise_block("Levantamento terra", "4x6"),
      exercise_block("Cadeira flexora", "3x12")
    ]

    patch periodization_version_workout_path(@version, @workout),
          params: { workout: { blocks: new_blocks } }

    assert_redirected_to periodization_version_path(@version)
    @workout.reload
    assert_equal 2, @workout.blocks.size
    assert_equal "Levantamento terra", @workout.blocks.first["name"]
    assert_equal "4x6", @workout.blocks.first["prescription"]
  end

  test "update with invalid blocks surfaces inertia errors and leaves the workout unchanged" do
    sign_in_as(@user)
    original_blocks = @workout.blocks
    invalid_blocks = [ { "kind" => "exercise", "prescription" => "3x10" } ] # missing name

    patch periodization_version_workout_path(@version, @workout),
          params: { workout: { blocks: invalid_blocks } }

    assert_redirected_to periodization_version_path(@version)
    errors = session[:inertia_errors] || {}
    assert errors.values.flatten.any? { |msg| msg.match?(/name ausente/i) },
           "expected pt-BR error about missing name, got: #{errors.inspect}"
    assert_equal original_blocks, @workout.reload.blocks
  end

  test "update on a promoted version redirects with flash alert and does not mutate" do
    @version.periodization.set_current_version!(@version)
    sign_in_as(@user)
    original_blocks = @workout.blocks

    patch periodization_version_workout_path(@version, @workout),
          params: { workout: { blocks: [ exercise_block("Outro", "3x5") ] } }

    assert_redirected_to periodization_version_path(@version)
    assert_match(/não pode/i, flash[:alert])
    assert_equal original_blocks, @workout.reload.blocks
  end

  test "update on a superseded version redirects with flash alert and does not mutate" do
    rec_v2 = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @user,
      kind: "periodization_edit_periodization"
    )
    @version.periodization.versions.create!(
      trainer: @user, voice_recording: rec_v2, parent_version: @version
    )
    sign_in_as(@user)
    original_blocks = @workout.blocks

    patch periodization_version_workout_path(@version, @workout),
          params: { workout: { blocks: [ exercise_block("Novo", "3x5") ] } }

    assert_redirected_to periodization_version_path(@version)
    assert_match(/não pode/i, flash[:alert])
    assert_equal original_blocks, @workout.reload.blocks
  end

  test "update honors a same-origin return_to query param" do
    sign_in_as(@user)
    new_blocks = [ exercise_block("Levantamento terra", "4x6") ]

    patch periodization_version_workout_path(@version, @workout),
          params: {
            workout: { blocks: new_blocks },
            return_to: student_agent_chat_path(@student, open_version_id: @version.id)
          }

    assert_redirected_to student_agent_chat_path(@student, open_version_id: @version.id)
  end

  test "update ignores an absolute-URL return_to and falls back to the version page" do
    sign_in_as(@user)

    patch periodization_version_workout_path(@version, @workout),
          params: {
            workout: { blocks: [ exercise_block("Outro", "3x5") ] },
            return_to: "https://evil.example.com/steal"
          }

    assert_redirected_to periodization_version_path(@version)
  end

  test "update is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    foreign_trainer = User.create!(
      email_address: "x@y.com", password: "password", organization: other_org
    )
    foreign_recording = VoiceRecording.create!(
      organization: other_org,
      student: foreign_student,
      trainer: foreign_trainer,
      kind: "periodization_create"
    )
    foreign_version = foreign_student.start_periodization!(
      trainer: foreign_trainer, voice_recording: foreign_recording
    )
    foreign_version.fork_with!(
      scope: :create,
      patch: {
        body_md: "## P",
        workouts: [ { name: "X", blocks: [ exercise_block("Y", "3x5") ], position: 1 } ]
      },
      trainer: foreign_trainer,
      voice_recording: foreign_recording
    )
    foreign_workout = foreign_version.workouts.first
    sign_in_as(@user)

    patch periodization_version_workout_path(foreign_version, foreign_workout),
          params: { workout: { blocks: [ exercise_block("Z", "3x5") ] } }

    assert_response :not_found
  end

  private
    def exercise_block(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end
end
