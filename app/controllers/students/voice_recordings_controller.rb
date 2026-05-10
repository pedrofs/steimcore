# frozen_string_literal: true

class Students::VoiceRecordingsController < InertiaController
  before_action :load_student
  before_action :load_recording, only: :show
  before_action :ensure_audio_present, only: :create

  def new
    @kind = resolve_kind(params[:kind])
    target_workout = load_target_workout(params[:target_workout_id]) if @kind == "periodization_edit_workout"
    @title = title_for(@kind)
    add_breadcrumb(label: "Alunos", path: students_path)
    add_breadcrumb(label: @student.name, path: student_path(@student))
    add_breadcrumb(label: @title, path: new_student_voice_recording_path(@student, kind: @kind, target_workout_id: target_workout&.id))

    render inertia: "students/voice_recordings/new", props: {
      student: { id: @student.id, name: @student.name },
      kind: @kind,
      target_workout: target_workout && { id: target_workout.id, name: target_workout.name, position: target_workout.position }
    }
  end

  def create
    kind = resolve_kind(params[:kind])
    target_workout = (kind == "periodization_edit_workout") ? load_target_workout(params[:target_workout_id]) : nil

    recording = @student.voice_recordings.new(
      organization: current_organization,
      trainer: Current.user,
      kind: kind,
      target_workout: target_workout
    )
    recording.audio.attach(params[:audio])
    recording.save!

    TranscribeJob.perform_later(recording.id)

    redirect_to student_voice_recording_path(@student, recording)
  end

  def show
    @title = title_for(@recording.kind, prefix: "Gravação")
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

    def ensure_audio_present
      return if params[:audio].present?

      redirect_to new_student_voice_recording_path(@student, kind: resolve_kind(params[:kind]), target_workout_id: params[:target_workout_id]),
                  alert: "Nenhum áudio recebido. Tente gravar novamente."
    end

    def resolve_kind(kind)
      VoiceRecording::KINDS.include?(kind) ? kind : "anamnesis"
    end

    def title_for(kind, prefix: "Gravar")
      case kind
      when "periodization_create" then "#{prefix} periodização"
      when "periodization_edit_workout" then "#{prefix} edição de treino"
      when "periodization_edit_periodization" then "#{prefix} edição da periodização"
      else "#{prefix} anamnese"
      end
    end

    def load_target_workout(id)
      return nil if id.blank?
      Workout
        .joins(periodization_version: { periodization: :student })
        .where(students: { organization_id: current_organization.id, id: @student.id })
        .find(id)
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
