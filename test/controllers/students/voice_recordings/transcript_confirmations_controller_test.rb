require "test_helper"

class Students::VoiceRecordings::TranscriptConfirmationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @user,
      kind: "anamnesis"
    )
    @recording.transition_to!(:transcribing)
    @recording.update!(transcript: "rascunho")
    @recording.transition_to!(:transcribed)
  end

  test "create writes the edited transcript and enqueues RegenerateAnamnesisJob" do
    sign_in_as(@user)

    assert_enqueued_with(job: RegenerateAnamnesisJob, args: [ @recording.id ]) do
      post student_voice_recording_transcript_confirmation_path(@student, @recording),
           params: { transcript: "Aluno relatou dor lombar." }
    end

    @recording.reload
    assert_equal "Aluno relatou dor lombar.", @recording.transcript
    assert_equal "generating", @recording.status
    assert_redirected_to student_voice_recording_path(@student, @recording)
  end

  test "create rejects an empty transcript" do
    sign_in_as(@user)

    post student_voice_recording_transcript_confirmation_path(@student, @recording),
         params: { transcript: "   " }

    assert_redirected_to student_voice_recording_path(@student, @recording)
    @recording.reload
    assert_equal "transcribed", @recording.status
  end

  test "create is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    other_student = other_org.students.create!(name: "Externo")
    foreign_recording = VoiceRecording.create!(
      organization: other_org,
      student: other_student,
      trainer: User.create!(email_address: "x@y.com", password: "password", organization: other_org),
      kind: "anamnesis"
    )
    sign_in_as(@user)

    post student_voice_recording_transcript_confirmation_path(other_student, foreign_recording),
         params: { transcript: "tentativa" }

    assert_response :not_found
  end
end
