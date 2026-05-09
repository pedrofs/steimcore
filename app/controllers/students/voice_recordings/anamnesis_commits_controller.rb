# frozen_string_literal: true

# Final step of the anamnesis flow: the trainer reviewed (and possibly edited)
# the proposed markdown and is committing it to the student record. We
# guard on `recording.status == "completed"` so the action is only available
# once the LLM has produced a proposal — earlier states (transcribing,
# generating, failed) cannot save anything because there's nothing reviewed.
class Students::VoiceRecordings::AnamnesisCommitsController < InertiaController
  def create
    student = current_organization.students.find(params[:student_id])
    recording = student.voice_recordings.find(params[:voice_recording_id])

    edited = params[:anamnesis_md].to_s

    if recording.status != "completed" || edited.strip.empty?
      redirect_to student_voice_recording_path(student, recording),
                  alert: edited.strip.empty? ? "A anamnese não pode ficar em branco." : "A geração da anamnese ainda não terminou."
      return
    end

    student.update!(anamnesis_md: edited)

    redirect_to student_path(student), notice: "Anamnese atualizada."
  end
end
