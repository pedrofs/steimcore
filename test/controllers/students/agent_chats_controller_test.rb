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
end
