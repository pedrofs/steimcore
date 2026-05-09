require "test_helper"

# Periodization-create flavour of the transcript confirmation flow. The
# anamnesis flavour is covered in transcript_confirmations_controller_test.rb.
class TranscriptConfirmationsPeriodizationTest < ActionDispatch::IntegrationTest
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
    @recording.transition_to!(:transcribing)
    @recording.update!(transcript: "rascunho")
    @recording.transition_to!(:transcribed)
  end

  test "create starts a periodization, enqueues GeneratePeriodizationJob, and redirects to the version page" do
    sign_in_as(@user)

    assert_enqueued_with(job: GeneratePeriodizationJob) do
      post student_voice_recording_transcript_confirmation_path(@student, @recording),
           params: { transcript: "Foco em hipertrofia, três treinos." }
    end

    @recording.reload
    assert_equal "generating", @recording.status
    assert_equal "Foco em hipertrofia, três treinos.", @recording.transcript

    @student.reload
    version = PeriodizationVersion.find_by!(voice_recording_id: @recording.id)
    assert_equal version.periodization_id, @student.active_periodization_id
    assert_redirected_to periodization_version_path(version)
  end
end
