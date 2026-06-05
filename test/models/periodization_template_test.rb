require "test_helper"

class PeriodizationTemplateTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    @version = completed_version_with_workouts
  end

  test "name is required" do
    template = @organization.periodization_templates.new(name: "")
    assert_not template.valid?
    assert template.errors[:name].any?
  end

  test "create_from_version! copies body_md, length, and workouts/blocks" do
    template = PeriodizationTemplate.create_from_version!(
      @version, name: "Iniciante 3x", description: "foco hipertrofia"
    )

    assert_equal "Iniciante 3x", template.name
    assert_equal "foco hipertrofia", template.description
    assert_equal "## Plano base", template.body_md
    assert_equal 8, template.periodization_length_weeks

    workouts = template.workouts.to_a
    assert_equal [ "A", "B" ], workouts.map(&:name)
    assert_equal [ 1, 2 ], workouts.map(&:position)
    assert_equal "Agachamento", workouts.first.blocks.first["name"]
    assert_equal "4x8", workouts.first.blocks.first["prescription"]
  end

  test "create_from_version! derives organization from the version's student" do
    template = PeriodizationTemplate.create_from_version!(@version, name: "X")

    assert_equal @student.organization, template.organization
    assert_includes @organization.periodization_templates, template
  end

  test "create_from_version! description defaults to nil" do
    template = PeriodizationTemplate.create_from_version!(@version, name: "X")
    assert_nil template.description
  end

  test "template is a snapshot independent of later edits to the source version" do
    template = PeriodizationTemplate.create_from_version!(@version, name: "X")

    # Mutate the source version after templatizing.
    @version.update!(body_md: "## Editado", periodization_length_weeks: 12)
    @version.workouts.first.update!(
      name: "Renomeado",
      blocks: [ { "kind" => "exercise", "name" => "Outro", "prescription" => "5x5" } ]
    )

    template.reload
    assert_equal "## Plano base", template.body_md
    assert_equal 8, template.periodization_length_weeks
    assert_equal "A", template.workouts.first.name
    assert_equal "Agachamento", template.workouts.first.blocks.first["name"]
  end

  private
    def completed_version_with_workouts
      version = @student.start_periodization!(trainer: @trainer)
      version.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano base",
          periodization_length_weeks: 8,
          workouts: [
            { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 },
            { name: "B", blocks: [ exercise_block("Supino", "4x8") ], position: 2 }
          ]
        },
        trainer: @trainer
      )
      version.transition_to!(:completed)
      version
    end

    def exercise_block(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end
end
