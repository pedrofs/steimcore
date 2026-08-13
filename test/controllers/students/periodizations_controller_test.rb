require "test_helper"

class Students::PeriodizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
  end

  test "index lists periodizations newest first, numbered oldest-first, badging the active one" do
    first = promoted_periodization(workouts: [ "A", "B" ])
    second = promoted_periodization(workouts: [ "A", "B", "C" ])
    sign_in_as(@user)

    get student_periodizations_path(@student)

    assert_response :success
    assert_equal "students/periodizations/index", inertia.component
    listed = inertia.props[:periodizations]
    assert_equal [ second.id, first.id ], listed.map { |p| p[:id] }
    assert_equal [ 2, 1 ], listed.map { |p| p[:ordinal] }
    assert_equal [ false, true ], listed.map { |p| p[:archived] }
  end

  test "index omits periodizations that never had a current version" do
    promoted = promoted_periodization(workouts: [ "A" ])
    failed_version = @student.start_periodization!(trainer: @user)
    failed_version.fail!("erro")
    sign_in_as(@user)

    get student_periodizations_path(@student)

    assert_response :success
    assert_equal [ promoted.id ], inertia.props[:periodizations].map { |p| p[:id] }
    assert_not_equal failed_version.periodization_id, promoted.id
  end

  test "index exposes the split, length and progress of each periodization" do
    @student.update!(weekly_frequency: 4)
    periodization = promoted_periodization(workouts: [ "A", "B" ])
    version = periodization.current_version
    TrainingSession.create!(
      student: @student,
      trainer: @user,
      periodization_version: version,
      workout: version.workouts.first,
      workout_name_snapshot: "A",
      workout_position_snapshot: 1,
      blocks_snapshot: version.workouts.first.blocks,
      finished_at: Time.current
    )
    sign_in_as(@user)

    get student_periodizations_path(@student)

    assert_response :success
    props = inertia.props[:periodizations].first
    assert_equal %w[A B], props[:workouts].map { |w| w[:name] }
    assert_equal 8, props[:length_weeks]
    assert_equal 32, props[:progress][:target]
    assert_equal 1, props[:progress][:sessions_done]
    assert_equal 31, props[:progress][:sessions_remaining]
    assert_equal student_periodization_path(@student, periodization), props[:path]
  end

  test "index renders for an archived student" do
    periodization = promoted_periodization(workouts: [ "A" ])
    @student.archive!
    sign_in_as(@user)

    get student_periodizations_path(@student)

    assert_response :success
    assert_equal [ periodization.id ], inertia.props[:periodizations].map { |p| p[:id] }
  end

  test "index is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    sign_in_as(@user)

    get student_periodizations_path(foreign_student)

    assert_response :not_found
  end

  test "new redirects to the agent chat" do
    sign_in_as(@user)

    get new_student_periodization_path(@student)

    assert_redirected_to student_agent_chat_path(@student)
  end

  test "new is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    sign_in_as(@user)

    get new_student_periodization_path(foreign_student)

    assert_response :not_found
  end

  test "show renders the active periodization with body and workouts" do
    version = @student.start_periodization!(trainer: @user)
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
      trainer: @user
    )
    version.transition_to!(:completed)
    periodization = version.periodization
    periodization.update!(current_version: version)

    sign_in_as(@user)
    get student_periodization_path(@student, periodization)

    assert_response :success
    assert_equal "students/periodizations/show", inertia.component
    props = inertia.props[:periodization]
    assert_equal periodization.id, props[:id]
    assert_equal "## Plano", props[:current_version][:body_md]
    assert_equal %w[A B], props[:current_version][:workouts].map { |w| w[:name] }
    assert_equal "exercise", props[:current_version][:workouts].first[:blocks].first["kind"]
  end

  test "show is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    foreign_periodization = foreign_student.periodizations.create!
    sign_in_as(@user)

    get student_periodization_path(foreign_student, foreign_periodization)

    assert_response :not_found
  end

  test "show includes completed versions in chronological order with authoring trainer, marking the current version" do
    other_trainer = User.create!(email_address: "outro@example.com", password: "password", organization: @organization)

    v1 = @student.start_periodization!(trainer: @user)
    v1.fork_with!(scope: :create, patch: { body_md: "## v1", periodization_length_weeks: 8, workouts: [
      { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 }
    ] }, trainer: @user)
    v1.transition_to!(:completed)
    periodization = v1.periodization
    periodization.set_current_version!(v1)

    v2 = periodization.start_edit!(scope: :periodization, trainer: other_trainer)
    v2.fork_with!(scope: :periodization, patch: { body_md: "## v2", periodization_length_weeks: 8, workouts: [
      { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 },
      { name: "C", blocks: [ exercise_block("Leg press", "4x10") ], position: 2 }
    ] }, trainer: other_trainer)
    v2.transition_to!(:completed)
    periodization.set_current_version!(v2)

    pending_version = periodization.versions.create!(trainer: @user, parent_version: v2)
    pending_version.transition_to!(:generating)
    failed_version = periodization.versions.create!(trainer: @user, parent_version: v2)
    failed_version.transition_to!(:generating)
    failed_version.fail!("erro")

    sign_in_as(@user)
    get student_periodization_path(@student, periodization)

    assert_response :success
    versions = inertia.props[:periodization][:versions]
    assert_equal [ v2.id, v1.id ], versions.map { |v| v[:id] }
    assert_equal [ other_trainer.email_address, @user.email_address ], versions.map { |v| v[:trainer][:email] }
    assert_equal [ true, false ], versions.map { |v| v[:current] }
  end

  test "show flags non-promoted, non-superseded completed versions as drafts" do
    v1 = @student.start_periodization!(trainer: @user)
    v1.fork_with!(scope: :create, patch: { body_md: "## v1", periodization_length_weeks: 8, workouts: [
      { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 }
    ] }, trainer: @user)
    v1.transition_to!(:completed)
    periodization = v1.periodization
    periodization.set_current_version!(v1)

    v2 = periodization.start_edit!(scope: :periodization, trainer: @user)
    v2.fork_with!(scope: :periodization, patch: { body_md: "## v2", periodization_length_weeks: 8, workouts: [
      { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 }
    ] }, trainer: @user)
    v2.transition_to!(:completed)
    periodization.set_current_version!(v2)

    v3 = periodization.start_edit!(scope: :periodization, trainer: @user)
    v3.fork_with!(scope: :periodization, patch: { body_md: "## v3", periodization_length_weeks: 8, workouts: [
      { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 }
    ] }, trainer: @user)
    v3.transition_to!(:completed)

    sign_in_as(@user)
    get student_periodization_path(@student, periodization)

    assert_response :success
    versions = inertia.props[:periodization][:versions]
    by_id = versions.index_by { |v| v[:id] }
    assert_equal false, by_id[v1.id][:draft], "v1 is superseded by v2 — not a draft"
    assert_equal false, by_id[v2.id][:draft], "v2 is promoted — not a draft"
    assert_equal true,  by_id[v3.id][:draft], "v3 is completed but neither promoted nor superseded"
  end

  private
    def exercise_block(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end

    # A block the student actually went through: a promoted version with the
    # given split. Starting a second one archives the first, exactly as the
    # renewal flow does.
    def promoted_periodization(workouts:)
      version = @student.start_periodization!(trainer: @user)
      version.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano",
          periodization_length_weeks: 8,
          workouts: workouts.each_with_index.map { |name, index|
            { name: name, blocks: [ exercise_block("Agachamento", "4x8") ], position: index + 1 }
          }
        },
        trainer: @user
      )
      version.transition_to!(:completed)
      version.periodization.tap { |p| p.set_current_version!(version) }
    end
end
