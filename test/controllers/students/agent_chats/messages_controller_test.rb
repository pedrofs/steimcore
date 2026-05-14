require "test_helper"

class Students::AgentChats::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @chat = @student.create_agent_chat!(
      organization: @organization,
      model: StudentAgent.chat_kwargs[:model]
    )
  end

  test "create persists a user message with content and enqueues the turn job" do
    sign_in_as(@user)

    assert_enqueued_with(job: Agent::RunTurnJob) do
      assert_difference -> { @chat.messages.count }, 1 do
        post student_agent_chat_messages_path(@student),
             params: { message: { content: "atualize a anamnese" } }
      end
    end

    assert_redirected_to student_agent_chat_path(@student)
    assert_equal "running", @chat.reload.state
    message = @chat.messages.order(:created_at).last
    assert_equal "user", message.role
    assert_equal "atualize a anamnese", message.content
  end

  test "create accepts attachments and persists them on the user message" do
    sign_in_as(@user)

    assert_difference -> { @chat.messages.count }, 1 do
      post student_agent_chat_messages_path(@student),
           params: { message: { content: "veja isto", attachments: [ fixture_audio_upload ] } }
    end

    assert_redirected_to student_agent_chat_path(@student)
    message = @chat.messages.order(:created_at).last
    assert message.attachments.attached?
    assert_equal 1, message.attachments.count
    assert_equal "anamnesis.webm", message.attachments.first.filename.to_s
  end

  test "create allows attachments-only messages with no text content" do
    sign_in_as(@user)

    assert_difference -> { @chat.messages.count }, 1 do
      post student_agent_chat_messages_path(@student),
           params: { message: { attachments: [ fixture_audio_upload ] } }
    end

    assert_redirected_to student_agent_chat_path(@student)
    message = @chat.messages.order(:created_at).last
    assert message.attachments.attached?
  end

  test "create with neither content nor attachments redirects without persisting" do
    sign_in_as(@user)

    assert_no_difference -> { @chat.messages.count } do
      post student_agent_chat_messages_path(@student), params: { message: { content: "" } }
    end
    assert_redirected_to student_agent_chat_path(@student)
    assert_equal "idle", @chat.reload.state
  end

  test "create rejects more than 5 attachments" do
    sign_in_as(@user)
    files = Array.new(6) { fixture_audio_upload }

    assert_no_difference -> { @chat.messages.count } do
      post student_agent_chat_messages_path(@student),
           params: { message: { content: "ok", attachments: files } }
    end
    assert_redirected_to student_agent_chat_path(@student)
    assert_match(/no máximo 5 arquivos/, flash[:alert])
  end

  test "create rejects an attachment larger than 20 MB" do
    sign_in_as(@user)
    big = Rack::Test::UploadedFile.new(
      StringIO.new("a" * (20.megabytes + 1)),
      "audio/webm",
      original_filename: "big.webm"
    )

    assert_no_difference -> { @chat.messages.count } do
      post student_agent_chat_messages_path(@student),
           params: { message: { content: "ok", attachments: [ big ] } }
    end
    assert_redirected_to student_agent_chat_path(@student)
    assert_match(/excede o limite de 20 MB/, flash[:alert])
  end

  test "create returns see_other and an alert when the chat is already running" do
    sign_in_as(@user)
    @chat.update!(state: :running)

    assert_no_difference -> { @chat.messages.count } do
      post student_agent_chat_messages_path(@student),
           params: { message: { content: "olá" } }
    end
    assert_response :see_other
    assert_match(/assistente ainda está respondendo/, flash[:alert])
  end

  test "show exposes attachment metadata in message props" do
    sign_in_as(@user)
    message = @chat.messages.create!(role: :user, content: "veja isto", trainer: @user)
    message.attachments.attach(
      io: StringIO.new("fake-audio-bytes"),
      filename: "anamnesis.webm",
      content_type: "audio/webm"
    )

    get student_agent_chat_path(@student)

    payload = inertia.props[:messages].first
    assert_equal 1, payload[:attachments].size
    attachment = payload[:attachments].first
    assert_equal "anamnesis.webm", attachment[:filename]
    assert_equal "audio/webm", attachment[:content_type]
    assert_equal "audio", attachment[:kind]
    assert attachment[:url].start_with?("/rails/")
  end

  private
    def fixture_audio_upload
      Rack::Test::UploadedFile.new(
        StringIO.new("fake-audio-bytes"),
        "audio/webm",
        original_filename: "anamnesis.webm"
      )
    end
end
