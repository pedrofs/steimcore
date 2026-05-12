class TrainingSession < ApplicationRecord
  include Blockable
  include Finishable
  include Swappable

  belongs_to :student
  belongs_to :trainer, class_name: "User"
  belongs_to :workout, optional: true

  validates :workout_name_snapshot, presence: true
  validates :workout_position_snapshot, presence: true, numericality: { only_integer: true }
  validate :validate_blocks_snapshot_schema

  # Begins a new active session for the student under the given trainer. Snapshots
  # the auto-picked workout (name, position, blocks) onto the session and assigns
  # the trainer/student/workout associations in a single transaction. Raises if
  # the student is ineligible (archived, no active periodization, current version
  # not completed, no workouts, or already has an active session).
  def self.start!(trainer:, student:)
    raise "Aluno está arquivado" if student.archived?

    periodization = student.active_periodization
    raise "Aluno não tem periodização ativa" if periodization.nil?

    version = periodization.current_version
    raise "Periodização ainda não está pronta" if version.nil? || version.status != "completed"

    workout = next_workout_for(student)
    raise "Periodização não tem treinos" if workout.nil?

    transaction do
      create!(
        student: student,
        trainer: trainer,
        workout: workout,
        workout_name_snapshot: workout.name,
        workout_position_snapshot: workout.position,
        blocks_snapshot: workout.blocks
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
    def validate_blocks_snapshot_schema
      Workout::Blocks.errors_for(blocks_snapshot).each { |message| errors.add(:blocks_snapshot, message) }
    end
end
