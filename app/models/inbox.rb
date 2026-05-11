# Trainer review queue. Aggregates a trainer's voice recordings into three
# groups (failed, ready, in_flight), each carrying the row data the inbox UI
# needs to render the queue and route click-throughs. This is a PORO query
# object — not a service — invoked from InboxesController#show. Personal scope
# only in this slice; org scope arrives later (issue #33).
class Inbox
  Row = Struct.new(
    :voice_recording_id, :kind, :student_id, :student_name,
    :label, :display_status, :error_message, :timestamp, :url,
    keyword_init: true
  )

  IN_FLIGHT_STATUSES = %w[pending transcribing transcribed generating].freeze
  PERIODIZATION_KINDS = %w[periodization_create periodization_edit_workout periodization_edit_periodization].freeze

  def initialize(trainer:)
    @trainer = trainer
  end

  def groups
    recordings = base_scope.includes(:student, :target_workout, periodization_version: :periodization).to_a

    {
      failed: failed_rows(recordings),
      ready: ready_rows(recordings),
      in_flight: in_flight_rows(recordings)
    }
  end

  private
    def base_scope
      VoiceRecording.where(trainer_id: @trainer.id)
    end

    def failed_rows(recordings)
      recordings
        .select { |r| r.status == "failed" && r.dismissed_at.nil? }
        .sort_by { |r| -r.created_at.to_f }
        .map { |r| build_row(r) }
    end

    def ready_rows(recordings)
      recordings
        .select { |r| ready?(r) }
        .sort_by { |r| r.created_at.to_f }
        .map { |r| build_row(r) }
    end

    def in_flight_rows(recordings)
      recordings
        .select { |r| IN_FLIGHT_STATUSES.include?(r.status) }
        .sort_by { |r| -r.created_at.to_f }
        .map { |r| build_row(r) }
    end

    def ready?(recording)
      return false unless recording.status == "completed"

      if recording.kind == "anamnesis"
        recording.proposed_anamnesis_md.present?
      else
        version = recording.periodization_version
        version.present? && version.status == "completed" && !version.promoted?
      end
    end

    def build_row(recording)
      Row.new(
        voice_recording_id: recording.id,
        kind: recording.kind,
        student_id: recording.student_id,
        student_name: recording.student.name,
        label: label_for(recording),
        display_status: display_status_for(recording),
        error_message: recording.error_message,
        timestamp: recording.created_at,
        url: url_for(recording)
      )
    end

    def label_for(recording)
      case recording.kind
      when "anamnesis"                          then "Anamnese"
      when "periodization_create"               then "Periodização"
      when "periodization_edit_workout"         then "Edição de treino — #{recording.target_workout&.name || "treino"}"
      when "periodization_edit_periodization"   then "Edição da periodização"
      else recording.kind
      end
    end

    def display_status_for(recording)
      case recording.status
      when "failed"
        "Falha"
      when "completed"
        recording.kind == "anamnesis" ? "Pronto para revisar" : "Pronto para revisar"
      when "pending", "transcribing", "transcribed"
        "Transcrevendo áudio…"
      when "generating"
        case recording.kind
        when "anamnesis" then "Gerando anamnese…"
        else                  "Gerando periodização…"
        end
      else
        recording.status
      end
    end

    def url_for(recording)
      case recording.status
      when "completed"
        case recording.kind
        when "anamnesis"
          Rails.application.routes.url_helpers.student_voice_recording_path(recording.student_id, recording.id)
        else
          version = recording.periodization_version
          version && Rails.application.routes.url_helpers.periodization_version_path(version)
        end
      when "failed"
        Rails.application.routes.url_helpers.student_voice_recording_path(recording.student_id, recording.id)
      else
        nil
      end
    end
end
