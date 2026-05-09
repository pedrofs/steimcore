class PeriodizationVersion < ApplicationRecord
  include JobStatusable
  include Forkable

  belongs_to :periodization
  belongs_to :trainer, class_name: "User"
  belongs_to :voice_recording, optional: true
  belongs_to :parent_version, class_name: "PeriodizationVersion", optional: true

  has_many :workouts, dependent: :destroy

  job_statuses transitions: {
    pending:    %i[generating failed],
    generating: %i[completed failed],
    completed:  [],
    failed:     %i[generating]
  }

  after_initialize :set_default_status, if: :new_record?

  def fail!(message)
    self.error_message = message
    transition_to!(:failed)
  end

  def promoted?
    periodization.current_version_id == id
  end

  private
    def set_default_status
      self.status ||= "pending"
    end
end
