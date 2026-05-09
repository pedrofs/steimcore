require "test_helper"

class PeriodizationVersionsControllerTest < ActionDispatch::IntegrationTest
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
  end

  test "show renders the version with workouts and body" do
    apply_completed_plan
    sign_in_as(@user)

    get periodization_version_path(@version)

    assert_response :success
    assert_equal "periodization_versions/show", inertia.component
    props = inertia.props[:version]
    assert_equal @version.id, props[:id]
    assert_equal "completed", props[:status]
    assert_equal "## Plano", props[:body_md]
    assert_equal 2, props[:workouts].size
    assert_equal false, props[:promoted]
  end

  test "show marks a superseded promoted version as read-only" do
    apply_completed_plan
    @version.periodization.update!(current_version: @version)

    rec_v2 = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @user,
      kind: "periodization_edit_periodization"
    )
    v2 = @version.periodization.start_edit!(scope: :periodization, trainer: @user, voice_recording: rec_v2)
    v2.fork_with!(scope: :periodization, patch: { body_md: "## v2", workouts: [
      { name: "A", content_md: "ag", position: 1 }
    ] }, trainer: @user, voice_recording: rec_v2)
    v2.transition_to!(:completed)
    @version.periodization.set_current_version!(v2)

    sign_in_as(@user)

    get periodization_version_path(@version)

    assert_response :success
    props = inertia.props[:version]
    assert_equal true, props[:read_only]
    assert_equal false, props[:promoted]
  end

  test "show leaves an in-review (just-generated, no descendants) version editable" do
    apply_completed_plan
    sign_in_as(@user)

    get periodization_version_path(@version)

    assert_response :success
    props = inertia.props[:version]
    assert_equal false, props[:read_only]
  end

  test "show is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    foreign_recording = VoiceRecording.create!(
      organization: other_org,
      student: foreign_student,
      trainer: User.create!(email_address: "x@y.com", password: "password", organization: other_org),
      kind: "periodization_create"
    )
    foreign_version = foreign_student.start_periodization!(trainer: foreign_recording.trainer, voice_recording: foreign_recording)
    sign_in_as(@user)

    get periodization_version_path(foreign_version)

    assert_response :not_found
  end

  test "update edits body_md and workouts on a completed, unpromoted version" do
    apply_completed_plan
    sign_in_as(@user)

    patch periodization_version_path(@version), params: {
      body_md: "## Plano editado",
      workouts: @version.workouts.order(:position).map.with_index do |w, i|
        { id: w.id, name: w.name, content_md: "edit-#{i}" }
      end
    }

    assert_redirected_to periodization_version_path(@version)
    @version.reload
    assert_equal "## Plano editado", @version.body_md
    assert_equal %w[edit-0 edit-1], @version.workouts.order(:position).pluck(:content_md)
  end

  test "update refuses to edit a still-generating version" do
    sign_in_as(@user)

    patch periodization_version_path(@version), params: { body_md: "x", workouts: [] }

    assert_redirected_to periodization_version_path(@version)
    assert_equal "", @version.reload.body_md
  end

  test "update refuses to edit a promoted version" do
    apply_completed_plan
    @version.periodization.update!(current_version: @version)
    sign_in_as(@user)

    patch periodization_version_path(@version), params: { body_md: "edit", workouts: [] }

    assert_redirected_to periodization_version_path(@version)
    assert_equal "## Plano", @version.reload.body_md
  end

  test "destroy discards an unpromoted version and archives a brand-new periodization" do
    sign_in_as(@user)
    periodization = @version.periodization

    delete periodization_version_path(@version)

    assert_redirected_to student_path(@student)
    assert_not PeriodizationVersion.exists?(@version.id)
    assert periodization.reload.archived?
    assert_nil @student.reload.active_periodization_id
  end

  test "destroy refuses to delete a promoted version" do
    apply_completed_plan
    @version.periodization.update!(current_version: @version)
    sign_in_as(@user)

    delete periodization_version_path(@version)

    assert_redirected_to periodization_version_path(@version)
    assert PeriodizationVersion.exists?(@version.id)
  end

  private
    def apply_completed_plan
      @version.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano",
          workouts: [
            { name: "A", content_md: "ag", position: 1 },
            { name: "B", content_md: "sup", position: 2 }
          ]
        },
        trainer: @user,
        voice_recording: @recording
      )
      @version.transition_to!(:completed)
    end
end
