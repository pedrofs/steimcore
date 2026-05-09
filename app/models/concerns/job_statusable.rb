# Mix in to expose a string `status` column with explicit, host-declared
# transition rules. Hosts call `transition_to!(:next_status)` and the concern
# enforces both the legality of the transition and that `error_message` is set
# whenever the new status is `:failed`.
#
# Each host declares its own transition table; that's why this lives as a
# cross-model concern but defers the lifecycle to the including model.
module JobStatusable
  extend ActiveSupport::Concern

  TERMINAL_STATUSES = %w[completed failed].freeze

  class_methods do
    # Declare the legal transitions, e.g.:
    #   job_statuses transitions: {
    #     pending:      %i[transcribing failed],
    #     transcribing: %i[transcribed failed],
    #     ...
    #   }
    def job_statuses(transitions:)
      @job_status_transitions = transitions.transform_keys(&:to_s).transform_values { |v| v.map(&:to_s) }
    end

    def job_status_transitions
      @job_status_transitions || {}
    end

    def job_statuses_all
      (job_status_transitions.keys + job_status_transitions.values.flatten).uniq
    end
  end

  included do
    validates :status, presence: true, inclusion: { in: ->(record) { record.class.job_statuses_all } }

    validate :status_change_is_legal
    validate :error_message_required_when_failed
  end

  def transition_to!(new_status)
    self.status = new_status.to_s
    save!
  end

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  private
    def status_change_is_legal
      return unless status_changed?
      return if status_was.blank? # initial assignment

      legal_next = self.class.job_status_transitions[status_was] || []
      return if legal_next.include?(status)

      errors.add(:status, "cannot transition from #{status_was.inspect} to #{status.inspect}")
    end

    def error_message_required_when_failed
      return unless status == "failed"
      return if error_message.present?

      errors.add(:error_message, "is required when status is failed")
    end
end
