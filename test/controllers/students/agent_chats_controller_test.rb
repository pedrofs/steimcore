require "test_helper"

class Students::AgentChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
  end

  test "show redirects unauthenticated visitors to sign in" do
    get student_agent_chat_path(@student)
    assert_redirected_to new_session_path
  end

  test "show lazily creates a chat scoped to the student's organization" do
    sign_in_as(@user)

    assert_difference -> { Agent::Chat.count }, 1 do
      get student_agent_chat_path(@student)
    end

    chat = @student.reload.agent_chat
    assert_equal @organization.id, chat.organization_id
    assert_equal "idle", chat.state
  end

  test "show reuses an existing chat on subsequent visits" do
    sign_in_as(@user)

    get student_agent_chat_path(@student)
    chat_id = @student.reload.agent_chat.id

    assert_no_difference -> { Agent::Chat.count } do
      get student_agent_chat_path(@student)
    end

    assert_equal chat_id, @student.reload.agent_chat.id
  end

  test "show renders the chat page with student props and an empty message list" do
    sign_in_as(@user)

    get student_agent_chat_path(@student)

    assert_response :success
    assert_equal "students/agent_chats/show", inertia.component
    assert_equal @student.id, inertia.props[:student][:id]
    assert_equal [], inertia.props[:messages]
  end

  test "show exposes open_version as nil when no open_version_id query param is given" do
    sign_in_as(@user)

    get student_agent_chat_path(@student)

    assert_response :success
    assert_nil inertia.props[:open_version]
  end

  test "show exposes open_version when open_version_id targets a version of one of the student's periodizations" do
    sign_in_as(@user)
    version = build_completed_version_for(@student)

    get student_agent_chat_path(@student, open_version_id: version.id)

    assert_response :success
    payload = inertia.props[:open_version]
    assert_equal version.id, payload[:id]
    assert_equal "completed", payload[:status]
    assert_equal "## Plano", payload[:body_md]
    assert_equal 2, payload[:workouts].size
  end

  test "show returns open_version as nil when the requested version belongs to another organization" do
    sign_in_as(@user)
    other_org = Organization.create!(name: "Outro Gym")
    foreign_trainer = User.create!(
      email_address: "outro@example.com", password: "password", organization: other_org
    )
    foreign_student = other_org.students.create!(name: "Externo")
    foreign_version = foreign_student.start_periodization!(trainer: foreign_trainer)

    get student_agent_chat_path(@student, open_version_id: foreign_version.id)

    assert_response :success
    assert_nil inertia.props[:open_version]
  end

  test "show returns open_version as nil when the requested version belongs to another student in the same org" do
    sign_in_as(@user)
    other_student = @organization.students.create!(name: "Outro Aluno")
    other_version = other_student.start_periodization!(trainer: @user)

    get student_agent_chat_path(@student, open_version_id: other_version.id)

    assert_response :success
    assert_nil inertia.props[:open_version]
  end

  test "show exposes has_active_periodization as false and empty suggestion_workouts when the student has no periodization" do
    sign_in_as(@user)

    get student_agent_chat_path(@student)

    assert_response :success
    assert_equal false, inertia.props[:has_active_periodization]
    assert_equal [], inertia.props[:suggestion_workouts]
  end

  test "show exposes has_active_periodization and the current version's workouts as suggestions" do
    sign_in_as(@user)
    version = build_completed_version_for(@student)
    @student.active_periodization.set_current_version!(version)

    get student_agent_chat_path(@student)

    assert_response :success
    assert_equal true, inertia.props[:has_active_periodization]
    workouts = inertia.props[:suggestion_workouts]
    assert_equal [ "A", "B" ], workouts.map { |w| w[:name] }
    assert_equal [ 1, 2 ], workouts.map { |w| w[:position] }
  end

  test "show caps suggestion_workouts at 3" do
    sign_in_as(@user)
    version = build_completed_version_with_workouts(@student, %w[A B C D E])
    @student.active_periodization.set_current_version!(version)

    get student_agent_chat_path(@student)

    assert_response :success
    assert_equal 3, inertia.props[:suggestion_workouts].size
    assert_equal [ "A", "B", "C" ], inertia.props[:suggestion_workouts].map { |w| w[:name] }
  end

  test "show returns empty suggestion_workouts when the periodization has no current_version yet" do
    sign_in_as(@user)
    @student.start_periodization!(trainer: @user)

    get student_agent_chat_path(@student)

    assert_response :success
    assert_equal true, inertia.props[:has_active_periodization]
    assert_equal [], inertia.props[:suggestion_workouts]
  end

  private
    def build_completed_version_for(student)
      version = student.start_periodization!(trainer: @user)
      version.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano",
          workouts: [
            { name: "A", blocks: [ { kind: "exercise", name: "Agachamento", prescription: "4x8" } ], position: 1 },
            { name: "B", blocks: [ { kind: "exercise", name: "Supino", prescription: "4x8" } ], position: 2 }
          ]
        },
        trainer: @user
      )
      version.transition_to!(:completed)
      version
    end

    def build_completed_version_with_workouts(student, names)
      version = student.start_periodization!(trainer: @user)
      workouts = names.each_with_index.map do |name, idx|
        { name: name, blocks: [ { kind: "exercise", name: "Agachamento", prescription: "4x8" } ], position: idx + 1 }
      end
      version.fork_with!(scope: :create, patch: { body_md: "## Plano", workouts: workouts }, trainer: @user)
      version.transition_to!(:completed)
      version
    end
end
