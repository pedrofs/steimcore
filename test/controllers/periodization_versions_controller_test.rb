require "test_helper"

class PeriodizationVersionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @version = @student.start_periodization!(trainer: @user)
  end

  test "show renders the version with workouts and body" do
    apply_completed_plan
    sign_in_as(@user)

    get periodization_version_path(@version)

    assert_response :success
    assert_equal "periodization_versions/show", inertia.component
    props = inertia.props[:version]
    assert_equal @version.id, props[:id]
    assert_equal "completed", props[:status]
    assert_equal "## Plano", props[:body_md]
    assert_equal 2, props[:workouts].size
    assert_equal "exercise", props[:workouts].first[:blocks].first["kind"]
    assert_equal false, props[:promoted]
  end

  test "show marks a superseded promoted version as read-only" do
    apply_completed_plan
    @version.periodization.update!(current_version: @version)

    v2 = @version.periodization.start_edit!(scope: :periodization, trainer: @user)
    v2.fork_with!(scope: :periodization, patch: { body_md: "## v2", workouts: [
      { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 }
    ] }, trainer: @user)
    v2.transition_to!(:completed)
    @version.periodization.set_current_version!(v2)

    sign_in_as(@user)

    get periodization_version_path(@version)

    assert_response :success
    props = inertia.props[:version]
    assert_equal true, props[:read_only]
    assert_equal false, props[:promoted]
  end

  test "show leaves an in-review (just-generated, no descendants) version editable" do
    apply_completed_plan
    sign_in_as(@user)

    get periodization_version_path(@version)

    assert_response :success
    props = inertia.props[:version]
    assert_equal false, props[:read_only]
  end

  test "show is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    foreign_trainer = User.create!(email_address: "x@y.com", password: "password", organization: other_org)
    foreign_version = foreign_student.start_periodization!(trainer: foreign_trainer)
    sign_in_as(@user)

    get periodization_version_path(foreign_version)

    assert_response :not_found
  end

  test "destroy discards an unpromoted version and archives a brand-new periodization" do
    sign_in_as(@user)
    periodization = @version.periodization

    delete periodization_version_path(@version)

    assert_redirected_to student_path(@student)
    assert_not PeriodizationVersion.exists?(@version.id)
    assert periodization.reload.archived?
    assert_nil @student.reload.active_periodization_id
  end

  test "destroy refuses to delete a promoted version" do
    apply_completed_plan
    @version.periodization.update!(current_version: @version)
    sign_in_as(@user)

    delete periodization_version_path(@version)

    assert_redirected_to periodization_version_path(@version)
    assert PeriodizationVersion.exists?(@version.id)
  end

  private
    def exercise_block(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end

    def apply_completed_plan
      @version.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano",
          workouts: [
            { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 },
            { name: "B", blocks: [ exercise_block("Supino", "4x8") ], position: 2 }
          ]
        },
        trainer: @user
      )
      @version.transition_to!(:completed)
    end
end
