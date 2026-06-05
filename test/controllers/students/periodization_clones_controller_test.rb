require "test_helper"

class Students::PeriodizationClonesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @template = template_for(@organization)
  end

  test "create clones the template into the student and redirects to the promoted plan" do
    sign_in_as(@user)

    assert_difference -> { @student.periodizations.count }, 1 do
      post student_periodization_clone_path(@student),
           params: { template_id: @template.id }
    end

    periodization = @student.reload.active_periodization
    assert_not_nil periodization
    assert_redirected_to student_periodization_path(@student, periodization)

    version = periodization.current_version
    assert_equal "completed", version.status
    assert_equal @user, version.trainer
    assert_equal [ "A", "B" ], version.workouts.order(:position).map(&:name)
  end

  test "create archives the prior active periodization, preserving the one-active invariant" do
    prior = @student.start_periodization!(trainer: @user).periodization
    sign_in_as(@user)

    post student_periodization_clone_path(@student), params: { template_id: @template.id }

    assert prior.reload.archived?
    cloned = @student.reload.active_periodization
    assert_not_equal prior.id, cloned.id
    assert_not cloned.archived?
  end

  test "create cannot clone another organization's template" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_template = template_for(other_org)
    sign_in_as(@user)

    assert_no_difference -> { @student.periodizations.count } do
      post student_periodization_clone_path(@student),
           params: { template_id: foreign_template.id }
    end

    assert_response :not_found
  end

  test "create is scoped to the current organization's students" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    sign_in_as(@user)

    post student_periodization_clone_path(foreign_student),
         params: { template_id: @template.id }

    assert_response :not_found
  end

  private
    def template_for(organization)
      organization.periodization_templates.create!(
        name: "Iniciante 3x",
        body_md: "## Plano base",
        periodization_length_weeks: 8,
        workouts: [
          PeriodizationTemplate::Workout.new(name: "A", position: 1, blocks: [ exercise_block("Agachamento", "4x8") ]),
          PeriodizationTemplate::Workout.new(name: "B", position: 2, blocks: [ exercise_block("Supino", "4x8") ])
        ]
      )
    end

    def exercise_block(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end
end
