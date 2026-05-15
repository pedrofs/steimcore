class Student < ApplicationRecord
  include Archivable

  belongs_to :organization
  belongs_to :active_periodization, class_name: "Periodization", optional: true
  has_many :periodizations, dependent: :destroy
  has_many :training_sessions, dependent: :destroy
  has_one :agent_chat, class_name: "Agent::Chat", as: :chattable, dependent: :destroy

  validates :name, presence: true

  scope :anamnesis_pending, -> { unarchived.where("anamnesis_md ~ '^\\s*$'") }
  scope :without_active_plan, -> { unarchived.where(active_periodization_id: nil) }

  # Students whose active periodization has unfinished trainer work — either a
  # failed generation or a completed draft that hasn't been promoted yet and
  # hasn't been superseded by a child fork. Generating versions are not matched
  # (they're "wait", not "act"); promoted current_versions are locked-in plans;
  # superseded versions are history.
  scope :plan_needs_action, -> {
    unarchived
      .joins("INNER JOIN periodizations ON periodizations.id = students.active_periodization_id AND periodizations.archived_at IS NULL")
      .joins("INNER JOIN periodization_versions ON periodization_versions.periodization_id = periodizations.id")
      .where(<<~SQL.squish)
        periodization_versions.status = 'failed'
        OR (
          periodization_versions.status = 'completed'
          AND periodization_versions.id IS DISTINCT FROM periodizations.current_version_id
          AND NOT EXISTS (
            SELECT 1 FROM periodization_versions child
            WHERE child.parent_version_id = periodization_versions.id
          )
        )
      SQL
      .distinct
  }

  # The created_at of the oldest PeriodizationVersion on this student's active
  # periodization that satisfies the plan_needs_action predicate (failed, or
  # completed-unpromoted-non-superseded). Used as the within-tag tiebreaker on
  # the dashboard so the longest-pending draft surfaces first. Returns nil when
  # there is no matching version.
  def plan_needs_action_sort_value
    return nil if active_periodization_id.nil?

    PeriodizationVersion
      .joins(:periodization)
      .where(periodization_id: active_periodization_id)
      .where(<<~SQL.squish)
        periodization_versions.status = 'failed'
        OR (
          periodization_versions.status = 'completed'
          AND periodization_versions.id IS DISTINCT FROM periodizations.current_version_id
          AND NOT EXISTS (
            SELECT 1 FROM periodization_versions child
            WHERE child.parent_version_id = periodization_versions.id
          )
        )
      SQL
      .minimum(:created_at)
  end

  def age(today: Date.current)
    return nil if birthday.nil?
    age = today.year - birthday.year
    age -= 1 if today < birthday + age.years
    age
  end

  # Begins a new periodization for this student. If an active one exists, it
  # gets archived in the same transaction; the new periodization is created
  # with a first PeriodizationVersion in :generating, the student is repointed
  # to the new periodization, and the new version is returned for the caller
  # to enqueue generation against.
  def start_periodization!(trainer:)
    transaction do
      active_periodization&.archive!

      new_periodization = periodizations.create!
      new_version = new_periodization.versions.create!(
        trainer: trainer,
        parent_version: nil
      )
      new_version.transition_to!(:generating)

      update!(active_periodization: new_periodization)

      new_version
    end
  end
end
