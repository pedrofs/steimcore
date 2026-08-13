# The server side of a **Mid-session edit** (ADR-0009): a trainer running a live
# session submits a new blocks array and the student's *plan* changes, not just
# today's performance — the correction holds next week too.
#
# One save is one transaction: fork a new version from the **Current version**
# (carrying every other Workout forward byte-identically and replacing the
# target Workout's blocks), complete it, promote it, re-point this session at
# the new version and its Workout, re-snapshot the blocks, and remap +progress+
# so the student's ticks follow their blocks. Forking and promotion go through
# the existing PeriodizationVersion::Forkable / Periodization APIs; nothing here
# reimplements them.
#
# The Workout a live session runs from belongs to a promoted (hence read-only)
# version, which is why editing forks rather than writes in place.
module TrainingSession::WorkoutRevisable
  extend ActiveSupport::Concern

  # Raised when the submitted blocks don't satisfy the shared Blocks schema.
  # Carries the pt-BR messages verbatim so the endpoint hands the trainer
  # exactly the strings the inline editor and the LLM pipeline produce.
  class InvalidBlocks < StandardError
    attr_reader :messages

    def initialize(messages)
      @messages = messages
      super(messages.join("; "))
    end
  end

  def revise_workout!(blocks:, origin_indices:, trainer:)
    raise ArgumentError, "sessão finalizada não pode ser editada" if finished_at.present?
    raise ArgumentError, "sessão não aponta para a versão atual do plano" if detached?

    messages = Blocks.errors_for(blocks)
    raise InvalidBlocks, messages if messages.any?

    target_workout = workout
    periodization = periodization_version.periodization

    new_version = nil
    transaction do
      new_version = fork_from_current(periodization, target_workout, blocks, trainer)
      periodization.set_current_version!(new_version)
      repoint_to!(new_version.workouts.find_by!(position: target_workout.position), new_version, origin_indices)
    end

    new_version
  end

  # A session whose plan has moved on since it started: its Workout or version
  # reference was nulled (both foreign keys are ON DELETE SET NULL, so this is a
  # legitimate state), another version was promoted, or the student was moved to
  # a different Periodization entirely. Forking from the Current version and
  # re-pointing such a session would splice the student onto a plan they did not
  # begin, so a **Mid-session edit** is refused.
  def detached?
    return true if workout_id.nil? || periodization_version_id.nil?

    periodization_version_id != student.active_periodization&.current_version_id
  end

  # Stable fingerprint of the blocks the editor loaded. The PATCH carries it back
  # so a concurrent change by another trainer is refused rather than remapped
  # against the wrong array.
  def blocks_digest
    Digest::SHA256.hexdigest(Array(blocks_snapshot).to_json)
  end

  private
    def fork_from_current(periodization, target_workout, blocks, trainer)
      version = periodization.versions.build(trainer: trainer, parent_version: periodization.current_version)
      version.fork_with!(
        scope: :workout,
        patch: { workout: { name: target_workout.name, blocks: blocks } },
        trainer: trainer,
        target_workout: target_workout
      )
      # Promotion requires a completed version, and reaching :completed is what
      # enqueues Linking — so names typed mid-session enter the catalog.
      version.transition_to!(:generating)
      version.complete!
      version
    end

    # The workout name and position snapshots are deliberately untouched: only
    # blocks are editable mid-session.
    def repoint_to!(new_workout, new_version, origin_indices)
      update!(
        workout: new_workout,
        periodization_version: new_version,
        blocks_snapshot: new_workout.blocks,
        progress: TrainingSession::ProgressRemap.remap(progress: progress, origin_indices: origin_indices)
      )
    end
end
