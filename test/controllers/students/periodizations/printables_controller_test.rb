require "test_helper"

class Students::Periodizations::PrintablesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
  end

  test "show renders the printable for a completed current version" do
    @student.update!(
      birthday: Date.new(1994, 1, 1),
      sex: "F",
      primary_goal: "Hipertrofia",
      weekly_frequency: 4,
      restrictions_summary: "Lesão no ombro direito."
    )
    promote_completed_plan!(workouts: [
      { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 },
      { name: "B", blocks: [ group_block("Superset", 3, [ "Supino", "Remada" ]) ], position: 2 },
      { name: "C", blocks: [ freeform_block("Aquecimento livre.") ], position: 3 }
    ])

    sign_in_as(@user)
    travel_to Time.zone.local(2026, 6, 1, 10, 0, 0) do
      get student_periodization_printable_path(@student)
    end

    assert_response :success
    assert_equal "students/periodizations/printables/show", inertia.component

    props = inertia.props
    assert_equal @student.id, props[:student][:id]
    assert_equal @student.name, props[:student][:name]
    assert_equal 32, props[:student][:age]
    assert_equal "F", props[:student][:sex]
    assert_equal "Hipertrofia", props[:student][:primary_goal]
    assert_equal 4, props[:student][:weekly_frequency]
    assert_equal "Lesão no ombro direito.", props[:student][:restrictions_summary]
    assert_equal @organization.name, props[:organization][:name]
    assert_equal "## Plano", props[:periodization][:body_md]
    assert_not_nil props[:periodization][:started_on]
    assert_equal %w[A B C], props[:periodization][:workouts].map { |w| w[:name] }
  end

  test "show uses the chrome-free application_print layout" do
    promote_completed_plan!(workouts: [
      { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 }
    ])

    sign_in_as(@user)
    get student_periodization_printable_path(@student)

    assert_response :success
    # The print layout has no sidebar/breadcrumb chrome — the body holds only the Inertia mount node.
    assert_select "aside", false
    assert_select "nav", false
    assert_select "[data-slot='sidebar-trigger']", false
  end

  test "show redirects with an alert when the student has no active periodization" do
    sign_in_as(@user)

    get student_periodization_printable_path(@student)

    assert_redirected_to student_path(@student)
    assert_match(/não há uma periodização ativa pronta para imprimir/i, flash[:alert])
  end

  test "show redirects with an alert when the current version is not completed" do
    version = @student.start_periodization!(trainer: @user)
    # Active periodization exists, but no current_version has been promoted yet.
    assert_nil version.periodization.current_version_id

    sign_in_as(@user)

    get student_periodization_printable_path(@student)

    assert_redirected_to student_periodization_path(@student, version.periodization)
    assert_match(/versão atual ainda não está pronta/i, flash[:alert])
  end

  test "show is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    sign_in_as(@user)

    get student_periodization_printable_path(foreign_student)

    assert_response :not_found
  end

  test "show renders successfully with all three block kinds mixed in one workout" do
    promote_completed_plan!(workouts: [
      { name: "A", position: 1, blocks: [
        freeform_block("Aquecimento: 5 min de esteira."),
        exercise_block("Agachamento", "4x8"),
        group_block("Superset", 3, [ "Supino", "Remada" ])
      ] }
    ])

    sign_in_as(@user)
    get student_periodization_printable_path(@student)

    assert_response :success
    workout_blocks = inertia.props[:periodization][:workouts].first[:blocks]
    assert_equal %w[freeform exercise group], workout_blocks.map { |b| b["kind"] }
  end

  private
    def exercise_block(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end

    def group_block(label, rounds, exercise_names)
      {
        "kind" => "group",
        "label" => label,
        "rounds" => rounds,
        "items" => exercise_names.map { |n| { "name" => n, "prescription" => "10 reps" } }
      }
    end

    def freeform_block(text)
      { "kind" => "freeform", "text_md" => text }
    end

    def promote_completed_plan!(workouts:)
      version = @student.start_periodization!(trainer: @user)
      version.fork_with!(
        scope: :create,
        patch: { body_md: "## Plano", workouts: workouts },
        trainer: @user
      )
      version.transition_to!(:completed)
      version.periodization.set_current_version!(version)
      version
    end
end
