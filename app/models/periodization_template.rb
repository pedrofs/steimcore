# An org-scoped, student-agnostic blueprint holding the same content a plan
# holds (`body_md`, `periodization_length_weeks`, ordered workouts with blocks).
# A separate hierarchy from Periodization/Workout (ADR-0008): mutable in place,
# no versioning or promotion, retired by hard `destroy`. Created v1 only by
# snapshotting a real version via `create_from_version!` ("Salvar como modelo").
class PeriodizationTemplate < ApplicationRecord
  belongs_to :organization
  has_many :workouts,
           -> { order(:position) },
           class_name: "PeriodizationTemplate::Workout",
           inverse_of: :periodization_template,
           dependent: :destroy

  validates :name, presence: true

  # Snapshots a version's content into a new org-scoped template, deriving the
  # organization from the version's student. The snapshot is a copy: editing the
  # source version afterward does not change the template, and vice-versa.
  def self.create_from_version!(version, name:, description: nil)
    organization = version.periodization.student.organization

    transaction do
      template = organization.periodization_templates.create!(
        name: name,
        description: description,
        body_md: version.body_md.to_s,
        periodization_length_weeks: version.periodization_length_weeks
      )

      version.workouts.order(:position).each do |workout|
        template.workouts.create!(
          name: workout.name,
          position: workout.position,
          blocks: workout.blocks
        )
      end

      template
    end
  end
end
