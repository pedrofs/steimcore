require "test_helper"

class PeriodizationTemplates::WorkoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @template = @organization.periodization_templates.create!(name: "Iniciante 3x", body_md: "## Plano")
    @workout = @template.workouts.create!(
      name: "A", position: 1, blocks: [ exercise_block("Agachamento", "4x8") ]
    )
  end

  test "update replaces the template workout's blocks in place" do
    sign_in_as(@user)
    new_blocks = [
      exercise_block("Levantamento terra", "4x6"),
      exercise_block("Cadeira flexora", "3x12")
    ]

    patch periodization_template_workout_path(@template, @workout),
          params: { workout: { blocks: new_blocks } }

    assert_redirected_to edit_periodization_template_path(@template)
    @workout.reload
    assert_equal 2, @workout.blocks.size
    assert_equal "Levantamento terra", @workout.blocks.first["name"]
    assert_equal "4x6", @workout.blocks.first["prescription"]
  end

  test "update with invalid blocks surfaces inertia errors and leaves the workout unchanged" do
    sign_in_as(@user)
    original_blocks = @workout.blocks
    invalid_blocks = [ { "kind" => "exercise", "prescription" => "3x10" } ] # missing name

    patch periodization_template_workout_path(@template, @workout),
          params: { workout: { blocks: invalid_blocks } }

    assert_redirected_to edit_periodization_template_path(@template)
    errors = session[:inertia_errors] || {}
    assert errors.values.flatten.any? { |msg| msg.match?(/name ausente/i) },
           "expected pt-BR error about missing name, got: #{errors.inspect}"
    assert_equal original_blocks, @workout.reload.blocks
  end

  test "update honors a same-origin return_to query param" do
    sign_in_as(@user)

    patch periodization_template_workout_path(@template, @workout),
          params: {
            workout: { blocks: [ exercise_block("Levantamento terra", "4x6") ] },
            return_to: periodization_template_path(@template)
          }

    assert_redirected_to periodization_template_path(@template)
  end

  test "update is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_template = other_org.periodization_templates.create!(name: "Plano alheio")
    foreign_workout = foreign_template.workouts.create!(
      name: "X", position: 1, blocks: [ exercise_block("Y", "3x5") ]
    )
    sign_in_as(@user)

    patch periodization_template_workout_path(foreign_template, foreign_workout),
          params: { workout: { blocks: [ exercise_block("Z", "3x5") ] } }

    assert_response :not_found
    assert_equal [ exercise_block("Y", "3x5") ], foreign_workout.reload.blocks
  end

  private
    def exercise_block(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end
end
