require "test_helper"

class Students::VoiceRecordingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
  end

  test "new redirects unauthenticated visitors to sign in" do
    get new_student_voice_recording_path(@student)
    assert_redirected_to new_session_path
  end

  test "new renders the recorder page" do
    sign_in_as(@user)

    get new_student_voice_recording_path(@student)

    assert_response :success
    assert_equal "students/voice_recordings/new", inertia.component
    assert_equal @student.id, inertia.props[:student][:id]
  end

  test "create accepts an audio upload, persists a pending recording, and enqueues TranscribeJob" do
    sign_in_as(@user)
    audio = fixture_audio_upload

    assert_enqueued_with(job: TranscribeJob) do
      assert_difference -> { VoiceRecording.count }, 1 do
        post student_voice_recordings_path(@student),
             params: { kind: "anamnesis", audio: audio }
      end
    end

    recording = VoiceRecording.order(:created_at).last
    assert_equal "pending", recording.status
    assert_equal "anamnesis", recording.kind
    assert_equal @student.id, recording.student_id
    assert_equal @user.id, recording.trainer_id
    assert_equal @organization.id, recording.organization_id
    assert recording.audio.attached?
    assert_redirected_to student_voice_recording_path(@student, recording)
  end

  test "create rejects requests without an audio attachment" do
    sign_in_as(@user)

    assert_no_difference -> { VoiceRecording.count } do
      post student_voice_recordings_path(@student), params: { kind: "anamnesis" }
    end

    assert_redirected_to new_student_voice_recording_path(@student)
    assert_match(/áudio/i, flash[:alert].to_s)
  end

  test "create is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    other_student = other_org.students.create!(name: "Externo")
    sign_in_as(@user)

    post student_voice_recordings_path(other_student),
         params: { kind: "anamnesis", audio: fixture_audio_upload }

    assert_response :not_found
  end

  test "show renders the polling page with current status" do
    recording = create_recording
    sign_in_as(@user)

    get student_voice_recording_path(@student, recording)

    assert_response :success
    assert_equal "students/voice_recordings/show", inertia.component
    props = inertia.props[:recording]
    assert_equal recording.id, props[:id]
    assert_equal "pending", props[:status]
    assert_equal @student.id, inertia.props[:student][:id]
  end

  test "show is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    other_student = other_org.students.create!(name: "Externo")
    foreign_recording = VoiceRecording.create!(
      organization: other_org,
      student: other_student,
      trainer: User.create!(email_address: "x@y.com", password: "password", organization: other_org),
      kind: "anamnesis"
    )
    sign_in_as(@user)

    get student_voice_recording_path(other_student, foreign_recording)

    assert_response :not_found
  end

  private
    def create_recording
      VoiceRecording.create!(
        organization: @organization,
        student: @student,
        trainer: @user,
        kind: "anamnesis"
      )
    end

    def fixture_audio_upload
      Rack::Test::UploadedFile.new(
        StringIO.new("fake-audio-bytes"),
        "audio/webm",
        original_filename: "anamnesis.webm"
      )
    end
end
