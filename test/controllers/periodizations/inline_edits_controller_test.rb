require "test_helper"

class Periodizations::InlineEditsControllerTest < ActionDispatch::IntegrationTest
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
    @periodization = @version.periodization
    @periodization.set_current_version!(@version)
  end

  test "create forks a clone of the current version and redirects to the new version" do
    sign_in_as(@user)

    assert_difference -> { @periodization.versions.count }, 1 do
      post periodization_inline_edit_path(@periodization)
    end

    new_version = @periodization.versions.order(:created_at).last
    assert_equal @version.id, new_version.parent_version_id
    assert_equal "completed", new_version.status
    assert_equal @version.body_md, new_version.body_md
    assert_equal @version.workouts.order(:position).pluck(:name, :position),
                 new_version.workouts.order(:position).pluck(:name, :position)

    assert_redirected_to periodization_version_path(new_version)
  end

  test "create redirects with flash error when the periodization has no current version" do
    @periodization.update!(current_version: nil)
    sign_in_as(@user)

    assert_no_difference -> { @periodization.versions.count } do
      post periodization_inline_edit_path(@periodization)
    end

    assert_redirected_to student_periodization_path(@student, @periodization)
    assert_match(/atual/i, flash[:alert])
  end

  test "create is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    foreign_periodization = foreign_student.periodizations.create!
    sign_in_as(@user)

    post periodization_inline_edit_path(foreign_periodization)

    assert_response :not_found
  end

  private
    def exercise_block(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end
end
