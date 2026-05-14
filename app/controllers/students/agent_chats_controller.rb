# frozen_string_literal: true

# Read view of the per-student agent chat. Finds or creates the chat lazily
# so the first visit is a normal idempotent GET — no separate "open chat"
# create action.
class Students::AgentChatsController < InertiaController
  before_action :load_student
  before_action :load_or_create_chat

  def show
    @title = "Chat — #{@student.name}"
    add_breadcrumb(label: "Alunos", path: students_path)
    add_breadcrumb(label: @student.name, path: student_path(@student))
    add_breadcrumb(label: "Chat", path: student_agent_chat_path(@student))

    render inertia: "students/agent_chats/show", props: {
      student: student_props(@student),
      chat: chat_props(@chat),
      messages: messages_props(@chat),
      open_version: open_version_props,
      has_active_periodization: @student.active_periodization_id.present?,
      suggestion_workouts: suggestion_workouts_props(@student)
    }
  end

  private
    def load_student
      @student = current_organization.students.find(params[:student_id])
    end

    def open_version_props
      version_id = params[:open_version_id].presence
      return nil unless version_id

      version = PeriodizationVersion
                .joins(:periodization)
                .where(periodizations: { student_id: @student.id })
                .find_by(id: version_id)
      return nil unless version

      version_props(version)
    end

    def version_props(version)
      {
        id: version.id,
        status: version.status,
        body_md: version.body_md,
        error_message: version.error_message,
        promoted: version.promoted?,
        read_only: version.read_only?,
        periodization_id: version.periodization_id,
        workouts: version.workouts.order(:position).map { |w|
          { id: w.id, name: w.name, position: w.position, blocks: w.blocks }
        }
      }
    end

    # Up to 3 workouts from the active periodization's current version, used by
    # the empty-state suggestion chips on the chat page. Returns [] when there
    # is no active periodization or no current_version yet (e.g. a generating
    # first version).
    def suggestion_workouts_props(student)
      version = student.active_periodization&.current_version
      return [] if version.nil?

      version.workouts.order(:position).limit(3).map do |workout|
        { id: workout.id, name: workout.name, position: workout.position }
      end
    end

    def load_or_create_chat
      @chat = @student.agent_chat || @student.create_agent_chat!(
        organization: current_organization,
        model: StudentAgent.chat_kwargs[:model]
      )
    end

    def student_props(student)
      {
        id: student.id,
        name: student.name,
        age: student.age,
        sex: student.sex,
        primary_goal: student.primary_goal,
        weekly_frequency: student.weekly_frequency,
        anamnesis_md: student.anamnesis_md
      }
    end

    def chat_props(chat)
      {
        id: chat.id,
        state: chat.state
      }
    end

    def messages_props(chat)
      chat.messages.order(:created_at).map { |message| message_props(message) }
    end

    def message_props(message)
      {
        id: message.id,
        role: message.role,
        content: message.content,
        created_at: message.created_at.iso8601,
        trainer_email_prefix: trainer_email_prefix(message.trainer),
        tool_calls: tool_calls_props(message),
        attachments: attachments_props(message)
      }
    end

    def attachments_props(message)
      return [] unless message.attachments.attached?

      message.attachments.map do |att|
        {
          id: att.id,
          filename: att.filename.to_s,
          content_type: att.content_type,
          byte_size: att.byte_size,
          url: Rails.application.routes.url_helpers.rails_blob_path(att, only_path: true),
          kind: attachment_kind(att.content_type)
        }
      end
    end

    def attachment_kind(content_type)
      case content_type.to_s
      when %r{\Aaudio/}      then "audio"
      when %r{\Aimage/}      then "image"
      when "application/pdf" then "pdf"
      else "file"
      end
    end

    def tool_calls_props(message)
      return [] if message.role.to_s != "assistant"

      message.tool_calls.order(:created_at).map do |tc|
        result_payload = result_payload_for(message, tc)
        {
          id: tc.id,
          name: tc.name,
          arguments: tc.arguments,
          result: result_payload
        }
      end
    end

    # The gem stores the tool's return value as the `content` of the next
    # `role: :tool` message, keyed by tool_call_id. Parse it back to a hash so
    # the frontend can render the card from the stable per-tool shape (e.g.
    # `summary_md` for update_anamnesis).
    def result_payload_for(_message, tool_call)
      result_message = tool_call.result_message
      return nil if result_message.nil?

      raw = result_message.content.to_s
      return nil if raw.empty?

      JSON.parse(raw)
    rescue JSON::ParserError
      { "raw" => raw }
    end

    def trainer_email_prefix(trainer)
      return nil if trainer.nil?
      trainer.email_address.to_s.split("@").first
    end
end
