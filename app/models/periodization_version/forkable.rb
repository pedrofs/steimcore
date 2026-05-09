# Applies an LLM-generated patch onto a PeriodizationVersion. The version is
# the receiver and gets mutated in-place: body_md is set, workouts are built.
# Future scopes (:periodization, :workout) carry forward the parent version's
# state and replace only the targeted slice; for this slice, only :create is
# implemented because the create flow has no parent to carry forward from.
module PeriodizationVersion::Forkable
  extend ActiveSupport::Concern

  def fork_with!(scope:, patch:, trainer:, voice_recording: nil)
    raise ArgumentError, "unknown fork scope #{scope.inspect}" unless scope.to_sym == :create
    raise ArgumentError, "create scope expects parent_version_id to be nil" if parent_version_id.present?

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
          content_md: (attrs[:content_md] || attrs["content_md"]).to_s,
          position: (attrs[:position] || attrs["position"]).to_i
        )
      end

      save!
    end

    self
  end
end
