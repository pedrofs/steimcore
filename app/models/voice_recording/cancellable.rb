# Cancels an in-flight VoiceRecording. Used by PeriodizationVersionsController
# when the trainer discards a draft that has voice jobs targeting it — the
# recording's terminal :cancelled status causes the running Generatable to
# return early without mutating any version.
#
# Idempotent: no-op when the recording is already in a terminal state.
module VoiceRecording::Cancellable
  extend ActiveSupport::Concern

  TERMINAL_STATUSES_FOR_CANCEL = %w[completed failed cancelled].freeze

  def cancel!
    return if TERMINAL_STATUSES_FOR_CANCEL.include?(status)

    transition_to!(:cancelled)
  end

  def cancelled?
    status == "cancelled"
  end
end
