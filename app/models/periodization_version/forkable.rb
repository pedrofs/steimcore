# Applies an LLM-generated patch to a PeriodizationVersion — either by forking
# a new version from a read-only parent (`fork_with!`) or by mutating an
# editable draft in place (`apply_patch!`).
#
# `fork_with!` scopes:
#   :create        — first version of a periodization. parent_version must be
#                    nil. patch is the full plan { body_md, workouts: [...] }.
#                    Each workout carries { name, position, blocks: [...] }.
#   :workout       — single-workout edit. parent_version is required and is
#                    carried forward (body_md unchanged, all workouts copied
#                    byte-identical). The workout at target_workout.position
#                    is replaced with the patch's { name, blocks }; position is
#                    preserved from the parent so positions remain stable
#                    across versions.
#   :periodization — whole-plan edit. parent_version is required but only as a
#                    parent pointer; body_md and the entire workouts array are
#                    replaced from the patch. Previous workouts are NOT carried
#                    forward — the AI returns the full updated plan, including
#                    any add/remove/reorder.
#   :clone         — byte-identical copy of parent_version. No patch, no LLM.
#                    Entry point from a promoted version into the inline editor:
#                    forks a fresh draft the trainer can hand-edit. The new
#                    version is born :completed (no async generation step) and
#                    has no voice_recording.
#
# `apply_patch!` scopes (mutate-in-place on an editable draft — no new row):
#   :workout       — replaces the receiver's workout at target_workout.position
#                    with the patch's { name, blocks }. Other workouts untouched.
#   :periodization — replaces the receiver's body_md and full workouts list.
#   :create/:clone — raise; these only make sense as fork operations.
module PeriodizationVersion::Forkable
  extend ActiveSupport::Concern

  def fork_with!(scope:, patch:, trainer:, voice_recording: nil, target_workout: nil)
    case scope.to_sym
    when :create
      raise ArgumentError, "create scope expects parent_version_id to be nil" if parent_version_id.present?
      apply_full_plan!(patch, trainer: trainer, voice_recording: voice_recording)
    when :workout
      raise ArgumentError, ":workout scope requires parent_version" if parent_version.nil?
      raise ArgumentError, ":workout scope requires target_workout" if target_workout.nil?
      apply_workout_carry_forward!(patch, target_workout: target_workout, trainer: trainer, voice_recording: voice_recording)
    when :periodization
      raise ArgumentError, ":periodization scope requires parent_version" if parent_version.nil?
      apply_full_plan!(patch, trainer: trainer, voice_recording: voice_recording)
    when :clone
      raise ArgumentError, ":clone scope expects a nil patch" unless patch.nil?
      raise ArgumentError, ":clone scope requires parent_version" if parent_version.nil?
      apply_clone!(trainer: trainer)
    else
      raise ArgumentError, "unknown fork scope #{scope.inspect}"
    end

    self
  end

  def apply_patch!(scope:, patch:, trainer:, voice_recording: nil, target_workout: nil)
    case scope.to_sym
    when :workout
      raise ArgumentError, ":workout scope requires target_workout" if target_workout.nil?
      apply_workout_in_place!(patch, target_workout: target_workout, trainer: trainer, voice_recording: voice_recording)
    when :periodization
      apply_full_plan!(patch, trainer: trainer, voice_recording: voice_recording)
    when :create, :clone
      raise ArgumentError, "#{scope.inspect} scope is not supported by apply_patch!"
    else
      raise ArgumentError, "unknown apply_patch! scope #{scope.inspect}"
    end

    self
  end

  private
    # Replaces body_md (from the patch) and the full workouts array. Used by
    # both `fork_with!(:create | :periodization)` and `apply_patch!(:periodization)`.
    def apply_full_plan!(patch, trainer:, voice_recording:)
      body_md = (patch[:body_md] || patch["body_md"]).to_s
      workouts_attrs = extract_workouts_attrs(patch)

      transaction do
        assign_attributes(
          body_md: body_md,
          trainer: trainer,
          voice_recording: voice_recording
        )

        workouts.destroy_all if workouts.loaded? || persisted?
        workouts_attrs.each { |attrs| workouts.build(attrs) }

        save!
      end
    end

    # Builds workouts on `self` by carrying forward parent_version.workouts and
    # replacing the one at target_workout.position with the patch. Used only
    # by `fork_with!(:workout)` since the receiver is a fresh fork.
    def apply_workout_carry_forward!(patch, target_workout:, trainer:, voice_recording:)
      patch_name, patch_blocks = extract_workout_patch(patch)
      target_position = target_workout.position

      transaction do
        assign_attributes(
          body_md: parent_version.body_md.to_s,
          trainer: trainer,
          voice_recording: voice_recording
        )

        workouts.destroy_all if workouts.loaded? || persisted?

        parent_version.workouts.order(:position).each do |parent_workout|
          if parent_workout.position == target_position
            workouts.build(name: patch_name, blocks: patch_blocks, position: parent_workout.position)
          else
            workouts.build(
              name: parent_workout.name,
              blocks: parent_workout.blocks,
              position: parent_workout.position
            )
          end
        end

        save!
      end
    end

    # Updates the receiver's existing workout at target_workout.position in
    # place. Other workouts and body_md remain untouched. Used by
    # `apply_patch!(:workout)`.
    def apply_workout_in_place!(patch, target_workout:, trainer:, voice_recording:)
      patch_name, patch_blocks = extract_workout_patch(patch)
      target_position = target_workout.position

      transaction do
        assign_attributes(trainer: trainer, voice_recording: voice_recording)

        target = workouts.find_by(position: target_position)
        raise ArgumentError, ":workout scope: no workout at position #{target_position}" if target.nil?
        target.update!(name: patch_name, blocks: patch_blocks)

        save!
      end
    end

    def apply_clone!(trainer:)
      transaction do
        assign_attributes(
          body_md: parent_version.body_md.to_s,
          trainer: trainer,
          voice_recording: nil
        )

        workouts.destroy_all if workouts.loaded? || persisted?

        parent_version.workouts.order(:position).each do |parent_workout|
          workouts.build(
            name: parent_workout.name,
            blocks: parent_workout.blocks,
            position: parent_workout.position
          )
        end

        save!
        transition_to!(:generating)
        complete!
      end
    end

    def extract_workouts_attrs(patch)
      (patch[:workouts] || patch["workouts"] || []).map do |attrs|
        {
          name: (attrs[:name] || attrs["name"]).to_s,
          blocks: normalize_blocks(attrs[:blocks] || attrs["blocks"]),
          position: (attrs[:position] || attrs["position"]).to_i
        }
      end
    end

    def extract_workout_patch(patch)
      workout_patch = patch[:workout] || patch["workout"] || {}
      name = (workout_patch[:name] || workout_patch["name"]).to_s
      blocks = normalize_blocks(workout_patch[:blocks] || workout_patch["blocks"])
      [ name, blocks ]
    end

    def normalize_blocks(value)
      return [] if value.nil?
      value
    end
end
