class TrainingSession < ApplicationRecord
  include Blockable
  include Finishable
  include Swappable
  include ExerciseLoadable

  belongs_to :student
  belongs_to :trainer, class_name: "User", optional: true
  belongs_to :workout, optional: true
  belongs_to :periodization_version, optional: true

  validates :workout_name_snapshot, presence: true
  validates :workout_position_snapshot, presence: true, numericality: { only_integer: true }
  validate :validate_blocks_snapshot_schema

  # Award Medals when a session becomes finished — covering both finish! and a
  # backdated log_past! (finished_at goes nil → present), and naturally skipping
  # reopen! (present → nil) since we guard on finished_at being present
  # (ADR-0005). The job re-evaluates the whole student idempotently.
  after_commit :enqueue_medal_evaluation, on: [ :create, :update ]

  # A student-initiated session has no trainer attached (ADR-0007). Only these
  # are cancelable by the student; trainer-initiated ones can be finished but
  # not discarded.
  def student_initiated?
    trainer_id.nil?
  end

  # Begins a new active session for the student, optionally under a trainer.
  # When no +trainer+ is given the session is student-initiated (trainer_id
  # null); when no +workout+ is given it defaults to the auto-picked
  # +next_workout_for+. Snapshots the workout (name, position, blocks) onto the
  # session and assigns the trainer/student/workout associations in a single
  # transaction. Raises if the student is ineligible (archived, no active
  # periodization, current version not completed, no workouts, or already has an
  # active session).
  def self.start!(student:, trainer: nil, workout: nil)
    raise "Aluno está arquivado" if student.archived?

    periodization = student.active_periodization
    raise "Aluno não tem periodização ativa" if periodization.nil?

    version = periodization.current_version
    raise "Periodização ainda não está pronta" if version.nil? || version.status != "completed"

    workout ||= next_workout_for(student)
    raise "Periodização não tem treinos" if workout.nil?

    transaction do
      create!(
        student: student,
        trainer: trainer,
        workout: workout,
        periodization_version: workout.periodization_version,
        workout_name_snapshot: workout.name,
        workout_position_snapshot: workout.position,
        blocks_snapshot: workout.blocks
      )
    end
  end

  # Creates a finished training session backdated to +on_date+ for the given
  # student/workout pair under +trainer+. Snapshots the workout name/position/
  # blocks the same way +start!+ does, and stamps created_at/finished_at to
  # noon on the chosen date so +Student::FrequencyView+ buckets the cell on the
  # right day. Raises if the student is archived, the date is in the future, or
  # the workout doesn't belong to the student's active periodization.
  def self.log_past!(trainer:, student:, on_date:, workout:)
    raise "Aluno está arquivado" if student.archived?
    raise "Data não pode ser futura" if on_date > Time.zone.today
    raise "Treino é obrigatório" if workout.nil?

    periodization = student.active_periodization
    raise "Aluno não tem periodização ativa" if periodization.nil?
    raise "Treino não pertence à periodização atual do aluno" \
      if workout.periodization_version_id != periodization.current_version_id

    timestamp = on_date.in_time_zone.noon

    transaction do
      create!(
        student: student,
        trainer: trainer,
        workout: workout,
        periodization_version: workout.periodization_version,
        workout_name_snapshot: workout.name,
        workout_position_snapshot: workout.position,
        blocks_snapshot: workout.blocks,
        created_at: timestamp,
        updated_at: timestamp,
        finished_at: timestamp
      )
    end
  end

  # Returns the workout the student should perform on their next session, per
  # the auto-pick rule: most-recent finished session's workout_position_snapshot
  # + 1, wrapping to the first workout; first-ever session returns the first
  # workout. Returns nil if the student is not eligible (no current version, or
  # no workouts).
  def self.next_workout_for(student)
    periodization = student.active_periodization
    return nil if periodization.nil?

    version = periodization.current_version
    return nil if version.nil?

    workouts = version.workouts.order(:position).to_a
    return nil if workouts.empty?

    last_finished = student.training_sessions
                           .where.not(finished_at: nil)
                           .order(finished_at: :desc)
                           .first
    return workouts.first if last_finished.nil?

    last_position = last_finished.workout_position_snapshot
    workouts.find { |w| w.position > last_position } || workouts.first
  end

  private
    def enqueue_medal_evaluation
      return unless saved_change_to_finished_at? && finished_at.present?

      MedalEvaluationJob.perform_later(student)
    end

    def validate_blocks_snapshot_schema
      Workout::Blocks.errors_for(blocks_snapshot).each { |message| errors.add(:blocks_snapshot, message) }
    end
end
