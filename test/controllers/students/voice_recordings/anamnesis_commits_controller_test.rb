require "test_helper"

class Students::VoiceRecordings::AnamnesisCommitsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @student.update!(anamnesis_md: "## Histórico\n\nLesão antiga.")

    @recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @user,
      kind: "anamnesis",
      transcript: "Aluno relatou dor no joelho.",
      proposed_anamnesis_md: "## Histórico\n\nLesão antiga.\n\n## Restrições\n\n- Joelho.",
      status: "completed"
    )
  end

  test "create updates the student's anamnesis_md with the trainer-edited markdown" do
    edited = "## Histórico\n\nLesão antiga.\n\n## Restrições\n\n- Joelho direito (corrigido).\n"
    sign_in_as(@user)

    post student_voice_recording_anamnesis_commit_path(@student, @recording),
         params: { anamnesis_md: edited }

    @student.reload
    assert_equal edited, @student.anamnesis_md
    assert_redirected_to student_path(@student)
  end

  test "create clears proposed_anamnesis_md on the recording so the inbox stops surfacing it" do
    sign_in_as(@user)

    post student_voice_recording_anamnesis_commit_path(@student, @recording),
         params: { anamnesis_md: "## Histórico\n\nLesão antiga." }

    assert_nil @recording.reload.proposed_anamnesis_md
  end

  test "create rejects an empty anamnesis_md" do
    original = @student.anamnesis_md
    sign_in_as(@user)

    post student_voice_recording_anamnesis_commit_path(@student, @recording),
         params: { anamnesis_md: "" }

    assert_redirected_to student_voice_recording_path(@student, @recording)
    assert_equal original, @student.reload.anamnesis_md
  end

  test "create only works on completed recordings" do
    pending = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @user,
      kind: "anamnesis",
      transcript: "rascunho"
    )
    pending.transition_to!(:transcribing)
    pending.transition_to!(:transcribed)
    sign_in_as(@user)

    post student_voice_recording_anamnesis_commit_path(@student, pending),
         params: { anamnesis_md: "qualquer coisa" }

    assert_redirected_to student_voice_recording_path(@student, pending)
    assert_equal "## Histórico\n\nLesão antiga.", @student.reload.anamnesis_md
  end
end
