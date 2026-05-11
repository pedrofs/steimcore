require "test_helper"

class InboxesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
  end

  test "show redirects unauthenticated visitors to sign in" do
    get inbox_path
    assert_redirected_to new_session_path
  end

  test "show renders the inbox page with three groups" do
    sign_in_as(@user)

    get inbox_path

    assert_response :success
    assert_equal "inbox/show", inertia.component
    groups = inertia.props[:groups]
    assert_kind_of Array, groups[:failed]
    assert_kind_of Array, groups[:ready]
    assert_kind_of Array, groups[:in_flight]
  end

  test "show returns only the current trainer's rows" do
    other_user = users(:two)
    other_recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: other_user,
      kind: "anamnesis"
    )
    other_recording.transition_to!(:transcribing)
    sign_in_as(@user)

    get inbox_path

    in_flight = inertia.props[:groups][:in_flight]
    refute_includes in_flight.map { |r| r[:voice_recording_id] }, other_recording.id
  end

  test "show row shape includes the expected fields" do
    recording = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @user,
      kind: "anamnesis"
    )
    recording.transition_to!(:transcribing)
    sign_in_as(@user)

    get inbox_path

    row = inertia.props[:groups][:in_flight].first
    assert_equal recording.id, row[:voice_recording_id]
    assert_equal "anamnesis", row[:kind]
    assert_equal @student.id, row[:student_id]
    assert_equal @student.name, row[:student_name]
    assert row.key?(:label)
    assert row.key?(:display_status)
    assert row.key?(:timestamp)
    assert row.key?(:url)
  end
end
