require "test_helper"

# Verifies the shared `Blockable` concern validates blocks identically for both
# `Workout` and `PeriodizationTemplate::Workout`, and that template workouts do
# NOT participate in the version-specific exercise-linking machinery.
class BlockableTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
  end

  MALFORMED_CASES = {
    "exercise missing name" => [ { "kind" => "exercise", "prescription" => "3x5" } ],
    "unknown kind"          => [ { "kind" => "mystery" } ],
    "group missing items"   => [ { "kind" => "group", "label" => "G" } ],
    "freeform missing text" => [ { "kind" => "freeform" } ]
  }.freeze

  MALFORMED_CASES.each do |label, blocks|
    test "Workout and PeriodizationTemplate::Workout reject the same malformed blocks (#{label}) with the same messages" do
      workout = build_workout(blocks)
      template_workout = build_template_workout(blocks)

      assert_not workout.valid?, "expected Workout to reject #{label}"
      assert_not template_workout.valid?, "expected template workout to reject #{label}"

      assert_equal workout.errors[:blocks].sort,
                   template_workout.errors[:blocks].sort,
                   "pt-BR block error messages must be identical across both models"
      assert template_workout.errors[:blocks].any?
    end
  end

  test "both models accept the same well-formed blocks" do
    blocks = [ { "kind" => "exercise", "name" => "Supino", "prescription" => "3x8" } ]

    assert build_workout(blocks).valid?
    assert build_template_workout(blocks).valid?
  end

  test "saving a PeriodizationTemplate::Workout does not enqueue exercise linking" do
    template = @organization.periodization_templates.create!(name: "T")

    assert_no_enqueued_jobs only: LinkExercisesJob do
      template.workouts.create!(
        name: "A",
        position: 1,
        blocks: [ { "kind" => "exercise", "name" => "Supino", "prescription" => "3x8" } ]
      )
    end
  end

  private
    def build_workout(blocks)
      periodization = @student.periodizations.create!
      version = periodization.versions.create!(trainer: @trainer, parent_version: nil)
      Workout.new(periodization_version: version, name: "A", position: 1, blocks: blocks)
    end

    def build_template_workout(blocks)
      template = @organization.periodization_templates.create!(name: "T")
      PeriodizationTemplate::Workout.new(
        periodization_template: template, name: "A", position: 1, blocks: blocks
      )
    end
end
