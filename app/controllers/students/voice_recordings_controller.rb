# frozen_string_literal: true

class Students::VoiceRecordingsController < InertiaController
  before_action :load_student
  before_action :load_recording, only: [ :show ]

  def new
    @title = "Gravar anamnese"
    add_breadcrumb(label: "Alunos", path: students_path)
    add_breadcrumb(label: @student.name, path: student_path(@student))
    add_breadcrumb(label: "Gravar anamnese", path: new_student_voice_recording_path(@student))

    render inertia: "students/voice_recordings/new", props: {
      student: { id: @student.id, name: @student.name }
    }
  end

  def create
    audio = params[:audio]

    if audio.blank?
      redirect_to new_student_voice_recording_path(@student),
                  alert: "Nenhum áudio recebido. Tente gravar novamente."
      return
    end

    recording = @student.voice_recordings.new(
      organization: current_organization,
      trainer: Current.user,
      kind: "anamnesis"
    )
    recording.audio.attach(audio)
    recording.save!

    TranscribeJob.perform_later(recording.id)

    redirect_to student_voice_recording_path(@student, recording)
  end

  def show
    @title = "Gravação de anamnese"
    add_breadcrumb(label: "Alunos", path: students_path)
    add_breadcrumb(label: @student.name, path: student_path(@student))
    add_breadcrumb(label: "Gravação", path: student_voice_recording_path(@student, @recording))

    render inertia: "students/voice_recordings/show", props: {
      student: { id: @student.id, name: @student.name, anamnesis_md: @student.anamnesis_md },
      recording: recording_props(@recording)
    }
  end

  private
    def load_student
      @student = current_organization.students.find(params[:student_id])
    end

    def load_recording
      @recording = @student.voice_recordings.find(params[:id])
    end

    def recording_props(recording)
      {
        id: recording.id,
        kind: recording.kind,
        status: recording.status,
        transcript: recording.transcript,
        proposed_anamnesis_md: recording.proposed_anamnesis_md,
        error_message: recording.error_message
      }
    end
end
