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

  test "create routes audio attachments into voice_clips, leaving :attachments empty" do
    sign_in_as(@user)

    assert_difference -> { @chat.messages.count }, 1 do
      post student_agent_chat_messages_path(@student),
           params: { message: { content: "veja isto", attachments: [ fixture_audio_upload ] } }
    end

    assert_redirected_to student_agent_chat_path(@student)
    message = @chat.messages.order(:created_at).last
    assert_not message.attachments.attached?
    assert message.voice_clips.attached?
    assert_equal 1, message.voice_clips.count
    assert_equal "anamnesis.webm", message.voice_clips.first.filename.to_s
  end

  test "create routes non-audio attachments into :attachments and audio into voice_clips" do
    sign_in_as(@user)

    post student_agent_chat_messages_path(@student),
         params: { message: { content: "misturado", attachments: [ fixture_audio_upload, fixture_image_upload ] } }

    message = @chat.messages.order(:created_at).last
    assert_equal 1, message.voice_clips.count
    assert_equal "anamnesis.webm", message.voice_clips.first.filename.to_s
    assert_equal 1, message.attachments.count
    assert_equal "photo.png", message.attachments.first.filename.to_s
  end

  test "create allows attachments-only messages with no text content" do
    sign_in_as(@user)

    assert_difference -> { @chat.messages.count }, 1 do
      post student_agent_chat_messages_path(@student),
           params: { message: { attachments: [ fixture_audio_upload ] } }
    end

    assert_redirected_to student_agent_chat_path(@student)
    message = @chat.messages.order(:created_at).last
    assert message.voice_clips.attached?
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

  test "show merges :attachments and :voice_clips into a single attachments props array" do
    sign_in_as(@user)
    message = @chat.messages.create!(role: :user, content: "veja isto", trainer: @user)
    message.attachments.attach(
      io: StringIO.new("fake-image-bytes"),
      filename: "photo.png",
      content_type: "image/png"
    )
    message.voice_clips.attach(
      io: StringIO.new("fake-audio-bytes"),
      filename: "anamnesis.webm",
      content_type: "audio/webm"
    )

    get student_agent_chat_path(@student)

    payload = inertia.props[:messages].first
    assert_equal 2, payload[:attachments].size
    kinds = payload[:attachments].map { |a| a[:kind] }
    assert_includes kinds, "image"
    assert_includes kinds, "audio"
    payload[:attachments].each { |a| assert a[:url].start_with?("/rails/") }
  end

  private
    def fixture_audio_upload
      Rack::Test::UploadedFile.new(
        StringIO.new("fake-audio-bytes"),
        "audio/webm",
        original_filename: "anamnesis.webm"
      )
    end

    def fixture_image_upload
      Rack::Test::UploadedFile.new(
        StringIO.new("fake-image-bytes"),
        "image/png",
        original_filename: "photo.png"
      )
    end
end
