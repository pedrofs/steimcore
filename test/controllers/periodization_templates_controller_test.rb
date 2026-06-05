require "test_helper"

class PeriodizationTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
  end

  test "index redirects unauthenticated visitors to sign in" do
    get periodization_templates_path
    assert_redirected_to new_session_path
  end

  test "index lists only the current organization's templates" do
    @organization.periodization_templates.create!(name: "Iniciante 3x", description: "hipertrofia")
    other_org = Organization.create!(name: "Outro Gym")
    other_org.periodization_templates.create!(name: "Plano alheio")

    sign_in_as(@user)
    get periodization_templates_path

    assert_response :success
    assert_equal "periodization_templates/index", inertia.component
    names = inertia.props[:templates].map { |t| t[:name] }
    assert_includes names, "Iniciante 3x"
    assert_not_includes names, "Plano alheio"
  end

  test "show renders the template's position-ordered workouts and blocks" do
    template = @organization.periodization_templates.create!(name: "Modelo", body_md: "## Plano")
    template.workouts.create!(name: "B", position: 2, blocks: [ exercise_block("Supino", "4x8") ])
    template.workouts.create!(name: "A", position: 1, blocks: [ exercise_block("Agachamento", "4x8") ])

    sign_in_as(@user)
    get periodization_template_path(template)

    assert_response :success
    assert_equal "periodization_templates/show", inertia.component
    workouts = inertia.props[:template][:workouts]
    assert_equal [ "A", "B" ], workouts.map { |w| w[:name] }
    assert_equal "Agachamento", workouts.first[:blocks].first["name"]
  end

  test "show is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    theirs = other_org.periodization_templates.create!(name: "Plano alheio")

    sign_in_as(@user)
    get periodization_template_path(theirs)

    assert_response :not_found
  end

  test "destroy hard-deletes the template and redirects to the library" do
    template = @organization.periodization_templates.create!(name: "Descartável")
    template.workouts.create!(name: "A", position: 1, blocks: [ exercise_block("Agachamento", "4x8") ])

    sign_in_as(@user)
    assert_difference -> { PeriodizationTemplate.count }, -1 do
      delete periodization_template_path(template)
    end

    assert_redirected_to periodization_templates_path
    assert_not PeriodizationTemplate.exists?(template.id)
  end

  test "destroy is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    theirs = other_org.periodization_templates.create!(name: "Plano alheio")

    sign_in_as(@user)
    assert_no_difference -> { PeriodizationTemplate.count } do
      delete periodization_template_path(theirs)
    end

    assert_response :not_found
  end

  private
    def exercise_block(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end
end
