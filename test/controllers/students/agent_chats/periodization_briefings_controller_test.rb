require "test_helper"

class Students::AgentChats::PeriodizationBriefingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
  end

  test "create seeds the briefing, enqueues the turn, and lands on the chat" do
    sign_in_as(@user)
    chat = @student.find_or_create_agent_chat!

    assert_enqueued_with(job: Agent::RunTurnJob) do
      assert_difference -> { chat.messages.count }, 1 do
        post student_agent_chat_periodization_briefing_path(@student)
      end
    end

    assert_redirected_to student_agent_chat_path(@student)
    assert_equal "running", chat.reload.state
    message = chat.messages.order(:created_at).last
    assert_equal "user", message.role
    assert_equal @user, message.trainer
    assert_match(/periodização para #{@student.name}/, message.content)
  end

  test "create opens the chat for a student who never had one" do
    sign_in_as(@user)
    assert_nil @student.agent_chat

    assert_difference -> { Agent::Chat.count }, 1 do
      post student_agent_chat_periodization_briefing_path(@student)
    end

    chat = @student.reload.agent_chat
    assert_equal @organization, chat.organization
    assert_equal 1, chat.messages.count
  end

  test "create returns see_other and an alert while a turn is in flight" do
    sign_in_as(@user)
    chat = @student.find_or_create_agent_chat!
    chat.update!(state: :running)

    assert_no_difference -> { chat.messages.count } do
      post student_agent_chat_periodization_briefing_path(@student)
    end

    assert_response :see_other
    assert_match(/assistente ainda está respondendo/, flash[:alert])
  end

  test "create is scoped to the signed-in trainer's organization" do
    sign_in_as(@user)
    other_student = Organization.create!(name: "Outro Gym").students.create!(name: "Fora da org")

    assert_no_difference -> { Agent::Chat.count } do
      post student_agent_chat_periodization_briefing_path(other_student)
    end

    assert_response :not_found
  end
end
