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

  test "edit renders the template for in-place editing, scoped to the organization" do
    template = @organization.periodization_templates.create!(name: "Modelo", body_md: "## Plano")
    template.workouts.create!(name: "A", position: 1, blocks: [ exercise_block("Agachamento", "4x8") ])

    sign_in_as(@user)
    get edit_periodization_template_path(template)

    assert_response :success
    assert_equal "periodization_templates/edit", inertia.component
    assert_equal "Modelo", inertia.props[:template][:name]
    assert_equal "Agachamento", inertia.props[:template][:workouts].first[:blocks].first["name"]
  end

  test "edit ships the exercise suggestion corpus for the inline workout editor" do
    supino = Exercise.create!(name: "Supino Reto")
    supino.aliases.create!(raw_name: "Supino reto c/ barra",
                           normalized_key: Exercise.normalize_name("Supino reto c/ barra"),
                           source: "llm")
    template = @organization.periodization_templates.create!(name: "Modelo")

    sign_in_as(@user)
    get edit_periodization_template_path(template)

    row = inertia.props[:exercise_suggestions].find { |s| s[:name] == "Supino Reto" }
    assert_equal supino.id, row[:id]
    assert_includes row[:keys], "supino reto"
    assert_includes row[:keys], "supino reto c/ barra"
  end

  test "edit is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    theirs = other_org.periodization_templates.create!(name: "Plano alheio")

    sign_in_as(@user)
    get edit_periodization_template_path(theirs)

    assert_response :not_found
  end

  test "update renames the template and edits its description" do
    template = @organization.periodization_templates.create!(name: "Antigo", description: "old")

    sign_in_as(@user)
    patch periodization_template_path(template),
          params: { periodization_template: { name: "Novo nome", description: "nova descrição" } }

    assert_redirected_to periodization_template_path(template)
    template.reload
    assert_equal "Novo nome", template.name
    assert_equal "nova descrição", template.description
  end

  test "update rejects a blank name and re-renders the edit surface" do
    template = @organization.periodization_templates.create!(name: "Mantém")

    sign_in_as(@user)
    patch periodization_template_path(template),
          params: { periodization_template: { name: "" } }

    assert_redirected_to edit_periodization_template_path(template)
    assert_equal "Mantém", template.reload.name
  end

  test "update is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    theirs = other_org.periodization_templates.create!(name: "Plano alheio")

    sign_in_as(@user)
    patch periodization_template_path(theirs),
          params: { periodization_template: { name: "Invadido" } }

    assert_response :not_found
    assert_equal "Plano alheio", theirs.reload.name
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
