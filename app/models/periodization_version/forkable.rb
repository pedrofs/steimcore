# Applies an LLM-generated patch onto a PeriodizationVersion. The version is
# the receiver and gets mutated in-place: body_md and workouts are set/built.
#
# Scopes:
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
      apply_workout!(patch, target_workout: target_workout, trainer: trainer, voice_recording: voice_recording)
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

  private
    def apply_full_plan!(patch, trainer:, voice_recording:)
      body_md = patch[:body_md] || patch["body_md"]
      workouts_attrs = patch[:workouts] || patch["workouts"] || []

      transaction do
        assign_attributes(
          body_md: body_md.to_s,
          trainer: trainer,
          voice_recording: voice_recording
        )

        workouts.destroy_all if workouts.loaded? || persisted?

        workouts_attrs.each do |attrs|
          workouts.build(
            name: (attrs[:name] || attrs["name"]).to_s,
            blocks: normalize_blocks(attrs[:blocks] || attrs["blocks"]),
            position: (attrs[:position] || attrs["position"]).to_i
          )
        end

        save!
      end
    end

    def apply_workout!(patch, target_workout:, trainer:, voice_recording:)
      workout_patch = patch[:workout] || patch["workout"] || {}
      patch_name = (workout_patch[:name] || workout_patch["name"]).to_s
      patch_blocks = normalize_blocks(workout_patch[:blocks] || workout_patch["blocks"])
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
            workouts.build(
              name: patch_name,
              blocks: patch_blocks,
              position: parent_workout.position
            )
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

    def normalize_blocks(value)
      return [] if value.nil?
      value
    end
end
