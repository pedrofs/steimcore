require "test_helper"

class PeriodizationVersions::TemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @version = completed_version_for(@student, @user)
  end

  test "create snapshots the version into a new org-scoped template and redirects" do
    sign_in_as(@user)

    assert_difference -> { @organization.periodization_templates.count }, 1 do
      post periodization_version_template_path(@version),
           params: { periodization_template: { name: "Iniciante 3x", description: "hipertrofia" } }
    end

    assert_redirected_to periodization_version_path(@version)
    template = @organization.periodization_templates.order(:created_at).last
    assert_equal "Iniciante 3x", template.name
    assert_equal "hipertrofia", template.description
    assert_equal [ "A", "B" ], template.workouts.map(&:name)
  end

  test "create with a blank name surfaces inertia errors and creates no template" do
    sign_in_as(@user)

    assert_no_difference -> { PeriodizationTemplate.count } do
      post periodization_version_template_path(@version),
           params: { periodization_template: { name: "" } }
    end

    assert_redirected_to periodization_version_path(@version)
    errors = session[:inertia_errors] || {}
    assert errors.key?("name") || errors.key?(:name),
           "expected a validation error on name, got: #{errors.inspect}"
  end

  test "create on a non-completed version is rejected with a flash alert" do
    pending_version = @student.start_periodization!(trainer: @user) # status :generating
    sign_in_as(@user)

    assert_no_difference -> { PeriodizationTemplate.count } do
      post periodization_version_template_path(pending_version),
           params: { periodization_template: { name: "X" } }
    end

    assert_redirected_to periodization_version_path(pending_version)
    assert_match(/concluída/i, flash[:alert])
  end

  test "create is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    foreign_trainer = User.create!(
      email_address: "x@y.com", password: "password", organization: other_org
    )
    foreign_version = completed_version_for(foreign_student, foreign_trainer)
    sign_in_as(@user)

    assert_no_difference -> { PeriodizationTemplate.count } do
      post periodization_version_template_path(foreign_version),
           params: { periodization_template: { name: "Roubado" } }
    end

    assert_response :not_found
  end

  private
    def completed_version_for(student, trainer)
      version = student.start_periodization!(trainer: trainer)
      version.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano",
          periodization_length_weeks: 8,
          workouts: [
            { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 },
            { name: "B", blocks: [ exercise_block("Supino", "4x8") ], position: 2 }
          ]
        },
        trainer: trainer
      )
      version.transition_to!(:completed)
      version
    end

    def exercise_block(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end
end
