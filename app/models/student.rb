class Student < ApplicationRecord
  include Archivable
  include SelfServeTrainable
  include Awardable
  include ExerciseLoadable

  belongs_to :organization
  belongs_to :student_identity, optional: true
  belongs_to :active_periodization, class_name: "Periodization", optional: true
  has_many :periodizations, dependent: :destroy
  has_many :training_sessions, dependent: :destroy
  has_many :student_medals, dependent: :destroy
  has_one :agent_chat, class_name: "Agent::Chat", as: :chattable, dependent: :destroy

  validates :name, presence: true

  # Lowering a cadence can retroactively unlock cadence-dependent Medals
  # (ADR-0005). Re-evaluate after the change commits; `workouts` is unaffected,
  # but the trigger is harmless and needed by the later cadence families.
  after_update_commit :enqueue_medal_evaluation, if: :saved_change_to_weekly_frequency?

  # Keep the cross-organization StudentIdentity link in sync with the per-org
  # contact email. When the email is present, find-or-create the identity keyed
  # by its normalised form and point the FK there; when cleared, drop the link.
  # Orphaned identities are left in place — they may still link other students
  # from other organizations.
  before_save :sync_student_identity, if: :sync_student_identity?

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

  # Students whose promoted plan has gone stale relative to their target
  # weekly frequency. The clock starts at the student's most-recent finished
  # session, or — if they've never trained — at the promoted version's
  # creation. The cutoff is adaptive: students who train more often are
  # flagged sooner. A null/zero weekly_frequency falls back to a 10-day cutoff
  # so partially-onboarded students still flow through the queue.
  scope :inactive, -> {
    unarchived
      .joins("INNER JOIN periodizations ON periodizations.id = students.active_periodization_id")
      .joins("INNER JOIN periodization_versions current_version ON current_version.id = periodizations.current_version_id")
      .where("current_version.status = 'completed'")
      .where(
        <<~SQL.squish,
          ? - COALESCE(
            (SELECT MAX(ts.finished_at) FROM training_sessions ts WHERE ts.student_id = students.id AND ts.finished_at IS NOT NULL),
            current_version.created_at
          ) > CASE
            WHEN students.weekly_frequency IS NULL OR students.weekly_frequency = 0
              THEN INTERVAL '10 days'
            ELSE (CEIL(7.0 / students.weekly_frequency * 2.0)::int) * INTERVAL '1 day'
          END
        SQL
        Time.current
      )
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

  # Timestamp the student's inactivity clock started ticking: the most-recent
  # finished session, falling back to the promoted version's created_at when
  # the student has never trained. Used as the within-tag tiebreaker on the
  # dashboard — older value = longer gap = sorts earlier. Returns nil when no
  # active periodization exists.
  def inactive_sort_value
    return nil if active_periodization_id.nil?

    last_finished_at = training_sessions.where.not(finished_at: nil).maximum(:finished_at)
    return last_finished_at if last_finished_at

    active_periodization.current_version&.created_at
  end

  # Students who have trained past their Periodization target without a new
  # Periodization being designed: the Current version is completed, the
  # student has an explicit weekly_frequency, the version carries a
  # periodization_length_weeks, and the finished session count across every
  # version of the Active periodization exceeds the resulting target.
  # Intentionally stricter than Student::PeriodizationProgress (which falls
  # back to DAYS_PER_WEEK when weekly_frequency is null/zero): the value
  # object lets the show page draw a progress bar with a default, but the
  # dashboard refuses to flag a student as overdue without an explicit
  # cadence — that would be a noisy tag built on a guess.
  scope :periodization_overdue, -> {
    unarchived
      .joins("INNER JOIN periodizations ON periodizations.id = students.active_periodization_id")
      .joins("INNER JOIN periodization_versions current_version ON current_version.id = periodizations.current_version_id")
      .where("current_version.status = 'completed'")
      .where("students.weekly_frequency > 0")
      .where("current_version.periodization_length_weeks IS NOT NULL")
      .where(<<~SQL.squish)
        (
          SELECT COUNT(*)
          FROM training_sessions ts
          JOIN periodization_versions pv ON pv.id = ts.periodization_version_id
          WHERE ts.student_id = students.id
            AND ts.finished_at IS NOT NULL
            AND pv.periodization_id = periodizations.id
        ) > current_version.periodization_length_weeks * students.weekly_frequency
      SQL
  }

  # Within-tag tiebreaker for the periodization_overdue dashboard cohort:
  # sessions_remaining, smaller-is-earlier so the most-overshot student (e.g.
  # -5) surfaces before a barely-overshot one (-1). Delegates to
  # Student::PeriodizationProgress so the SQL scope and Ruby value stay aligned.
  def periodization_overdue_sort_value
    PeriodizationProgress.new(self).sessions_remaining
  end

  # Students within 5 sessions of finishing their Periodization target: the
  # Current version is completed, the student has an explicit
  # weekly_frequency, the version carries a periodization_length_weeks, and
  # the finished session count across every version of the Active
  # periodization leaves sessions_remaining in [0, 5) — i.e. the count sits
  # in (target − 5, target]. Same strict-cadence guard as
  # periodization_overdue: Student::PeriodizationProgress#due? falls back to
  # DAYS_PER_WEEK on the show page, but the dashboard requires an explicit
  # weekly_frequency before nudging the trainer to replan. Mutually
  # exclusive with periodization_overdue by construction.
  scope :periodization_due, -> {
    unarchived
      .joins("INNER JOIN periodizations ON periodizations.id = students.active_periodization_id")
      .joins("INNER JOIN periodization_versions current_version ON current_version.id = periodizations.current_version_id")
      .where("current_version.status = 'completed'")
      .where("students.weekly_frequency > 0")
      .where("current_version.periodization_length_weeks IS NOT NULL")
      .where(<<~SQL.squish)
        (
          SELECT COUNT(*)
          FROM training_sessions ts
          JOIN periodization_versions pv ON pv.id = ts.periodization_version_id
          WHERE ts.student_id = students.id
            AND ts.finished_at IS NOT NULL
            AND pv.periodization_id = periodizations.id
        ) BETWEEN current_version.periodization_length_weeks * students.weekly_frequency - 4
              AND current_version.periodization_length_weeks * students.weekly_frequency
      SQL
  }

  # Within-tag tiebreaker for the periodization_due dashboard cohort:
  # sessions_remaining, smaller-is-earlier so the most-imminent replan (0)
  # surfaces before one with more runway (4). Delegates to
  # Student::PeriodizationProgress so the SQL scope and Ruby value stay aligned.
  def periodization_due_sort_value
    PeriodizationProgress.new(self).sessions_remaining
  end

  # Number of Periodizations the student has trained to completion — the full
  # prescribed dose delivered (Sessions remaining <= 0), counting both the
  # Active block and archived ones. Reuses Student::PeriodizationProgress for the
  # per-block Sessions-remaining math (ADR-0002): a block whose Current version
  # carries no periodization_length_weeks (not applicable?) and a block scrapped
  # early before the dose landed (remaining > 0) are both excluded. Feeds the
  # `periodizations` Medal family (ADR-0005); returns nil — leaving the family
  # locked — without an explicit weekly_frequency, matching the no-fallback
  # cadence rule of the dashboard scopes. Because we gate on a positive cadence
  # here, PeriodizationProgress's DAYS_PER_WEEK fallback is never reached.
  def completed_periodizations_count
    return nil unless weekly_frequency.to_i.positive?

    periodizations.count do |periodization|
      progress = PeriodizationProgress.new(self, periodization: periodization)
      progress.applicable? && !progress.sessions_remaining.positive?
    end
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

  private
    def enqueue_medal_evaluation
      MedalEvaluationJob.perform_later(self)
    end

    # Resync whenever the email changed, or when an email is present but the FK
    # is still missing (covers rows created before identities existed).
    def sync_student_identity?
      email_changed? || (email.present? && student_identity_id.nil?)
    end

    def sync_student_identity
      normalized = email.to_s.strip.downcase.presence
      self.student_identity = normalized && StudentIdentity.find_or_create_by!(email_address: normalized)
    end
end
