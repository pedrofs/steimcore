class PeriodizationVersion < ApplicationRecord
  include JobStatusable
  include Forkable

  belongs_to :periodization
  belongs_to :trainer, class_name: "User"
  belongs_to :agent_tool_call, class_name: "Agent::ToolCall", optional: true
  belongs_to :parent_version, class_name: "PeriodizationVersion", optional: true

  has_many :workouts, dependent: :destroy

  job_statuses transitions: {
    pending:    %i[generating failed],
    generating: %i[completed failed],
    completed:  %i[generating],
    failed:     %i[generating]
  }

  after_initialize :set_default_status, if: :new_record?

  def complete!
    transition_to!(:completed)
  end

  def fail!(message)
    self.error_message = message
    transition_to!(:failed)
  end

  def promoted?
    periodization.current_version_id == id
  end

  # A version is "superseded" when another version was forked from it. In the
  # edit flow, start_edit! sets parent_version on the new version to the prior
  # current_version, so the prior current_version develops descendants the
  # moment a successor is created. We use this as the signal that this version
  # is locked-in history rather than an in-review draft.
  def superseded?
    PeriodizationVersion.where(parent_version_id: id).exists?
  end

  # A version is read-only when it is no longer the working draft — either it
  # has been promoted, or it has been superseded by a child fork.
  def read_only?
    promoted? || superseded?
  end

  private
    def set_default_status
      self.status ||= "pending"
    end
end
