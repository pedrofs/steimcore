class Periodization < ApplicationRecord
  include Archivable

  belongs_to :student
  belongs_to :current_version, class_name: "PeriodizationVersion", optional: true
  has_many :versions, class_name: "PeriodizationVersion", dependent: :destroy

  def set_current_version!(version)
    raise ArgumentError, "version must belong to this periodization" unless version.periodization_id == id
    update!(current_version: version)
  end

  # Begins a new pending PeriodizationVersion derived from current_version. The
  # caller is responsible for enqueueing generation against the returned
  # version. Promotion is deliberately deferred until the trainer reviews the
  # generated patch.
  def start_edit!(scope:, trainer:, target_workout: nil)
    raise ArgumentError, "current_version must be set before editing" if current_version.nil?

    case scope.to_sym
    when :workout
      raise ArgumentError, ":workout scope requires target_workout" if target_workout.nil?
      raise ArgumentError, "target_workout must belong to current_version" unless target_workout.periodization_version_id == current_version_id
    when :periodization
      # Whole-plan edit: no target_workout required.
    else
      raise ArgumentError, "unknown edit scope #{scope.inspect}"
    end

    transaction do
      new_version = versions.create!(
        trainer: trainer,
        parent_version: current_version
      )
      new_version.transition_to!(:generating)
      new_version
    end
  end
end
