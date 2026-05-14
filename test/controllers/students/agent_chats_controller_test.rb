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
end
