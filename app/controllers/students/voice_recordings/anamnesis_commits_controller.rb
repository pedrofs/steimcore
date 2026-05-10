# frozen_string_literal: true

# Final step of the anamnesis flow: the trainer reviewed (and possibly edited)
# the proposed markdown and is committing it to the student record. We
# guard on `recording.status == "completed"` so the action is only available
# once the LLM has produced a proposal — earlier states (transcribing,
# generating, failed) cannot save anything because there's nothing reviewed.
class Students::VoiceRecordings::AnamnesisCommitsController < InertiaController
  before_action :load_student_and_recording
  before_action :ensure_recording_completed_and_value_present

  def create
    @student.update!(anamnesis_md: edited_anamnesis)

    redirect_to student_path(@student), notice: "Anamnese atualizada."
  end

  private
    def load_student_and_recording
      @student = current_organization.students.find(params[:student_id])
      @recording = @student.voice_recordings.find(params[:voice_recording_id])
    end

    def edited_anamnesis
      @edited_anamnesis ||= params[:anamnesis_md].to_s
    end

    def ensure_recording_completed_and_value_present
      return if @recording.status == "completed" && !edited_anamnesis.strip.empty?

      redirect_to student_voice_recording_path(@student, @recording),
                  alert: edited_anamnesis.strip.empty? ? "A anamnese não pode ficar em branco." : "A geração da anamnese ainda não terminou."
    end
end
