require "test_helper"

# Exercises the read-only "prepare the payload" layer. Every test asserts two
# things: the right rows are SELECTED for the API, and the persisted history is
# left completely untouched (no deletes, no content rewrites).
class Agent::Chat::MessageSelectionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @chat = @student.create_agent_chat!(
      organization: @organization,
      state: :idle,
      model: StudentAgent.chat_kwargs[:model]
    )
    @first_user = @chat.messages.create!(role: :user, content: "Olá", trainer: @user)
  end

  # Convenience: the [role, content] pairs of the selected payload.
  def selected
    @chat.messages_for_llm.map { |m| [ m.role.to_s, m.content.to_s ] }
  end

  test "a clean alternating history passes through unchanged" do
    @chat.messages.create!(role: :assistant, content: "Oi!")
    @chat.messages.create!(role: :user, content: "tudo bem?", trainer: @user)

    assert_equal [ [ "user", "Olá" ], [ "assistant", "Oi!" ], [ "user", "tudo bem?" ] ], selected
  end

  test "drops an empty user row from the payload but keeps it persisted" do
    @chat.messages.create!(role: :assistant, content: "Pode falar")
    @chat.messages.create!(role: :user, content: "", trainer: @user)

    assert_no_difference -> { @chat.messages.count } do
      assert_equal [ [ "user", "Olá" ], [ "assistant", "Pode falar" ] ], selected
    end
  end

  test "keeps an empty user row that still carries voice clips (not debris)" do
    @chat.messages.create!(role: :assistant, content: "Pode falar")
    clip = @chat.messages.create!(role: :user, content: "", trainer: @user)
    clip.voice_clips.attach(io: StringIO.new("audio"), filename: "c.webm", content_type: "audio/webm")

    roles = @chat.messages_for_llm.map { |m| m.role.to_s }
    assert_equal [ "user", "assistant", "user" ], roles
  end

  test "consecutive user runs collapse to the latest message without merging content" do
    @chat.messages.create!(role: :assistant, content: "Pode mandar")
    @chat.messages.create!(role: :user, content: "primeira", trainer: @user)
    @chat.messages.create!(role: :user, content: "segunda",  trainer: @user)
    @chat.messages.create!(role: :user, content: "terceira", trainer: @user)

    assert_no_difference -> { @chat.messages.count } do
      assert_equal [ [ "user", "Olá" ], [ "assistant", "Pode mandar" ], [ "user", "terceira" ] ], selected
    end
  end

  test "consecutive text-only assistant runs collapse to the latest" do
    @chat.messages.create!(role: :assistant, content: "primeira parte")
    @chat.messages.create!(role: :assistant, content: "segunda parte")

    assert_equal [ [ "user", "Olá" ], [ "assistant", "segunda parte" ] ], selected
  end

  test "drops an orphan assistant tool_use (no matching tool_result) from the payload" do
    assistant = @chat.messages.create!(role: :assistant, content: "")
    assistant.tool_calls.create!(tool_call_id: "toolu_orphan", name: "update_anamnesis", arguments: {})

    assert_no_difference -> { @chat.messages.count } do
      assert_equal [ [ "user", "Olá" ] ], selected
    end
  end

  test "keeps an assistant tool_use whose tool_result is present" do
    assistant = @chat.messages.create!(role: :assistant, content: "")
    tc = assistant.tool_calls.create!(tool_call_id: "toolu_ok", name: "update_anamnesis", arguments: {})
    @chat.messages.create!(role: :tool, tool_call_id: tc.id, content: "{ok: true}")

    roles = @chat.messages_for_llm.map { |m| m.role.to_s }
    assert_equal [ "user", "assistant", "tool" ], roles
  end

  test "drops a tool_result whose owning assistant tool_use was dropped" do
    # Assistant has two tool_calls; only one is answered, so the assistant is an
    # orphan and gets dropped — its answered tool_result must go too.
    assistant = @chat.messages.create!(role: :assistant, content: "")
    answered = assistant.tool_calls.create!(tool_call_id: "toolu_a", name: "update_anamnesis", arguments: {})
    assistant.tool_calls.create!(tool_call_id: "toolu_b", name: "update_student", arguments: {})
    @chat.messages.create!(role: :tool, tool_call_id: answered.id, content: "{ok: true}")

    assert_equal [ [ "user", "Olá" ] ], selected
  end

  test "leaves multiple tool_result rows for one assistant turn intact" do
    assistant = @chat.messages.create!(role: :assistant, content: "")
    tc1 = assistant.tool_calls.create!(tool_call_id: "toolu_1", name: "update_anamnesis", arguments: {})
    tc2 = assistant.tool_calls.create!(tool_call_id: "toolu_2", name: "update_student", arguments: {})
    @chat.messages.create!(role: :tool, tool_call_id: tc1.id, content: "{ok: 1}")
    @chat.messages.create!(role: :tool, tool_call_id: tc2.id, content: "{ok: 2}")

    roles = @chat.messages_for_llm.map { |m| m.role.to_s }
    assert_equal [ "user", "assistant", "tool", "tool" ], roles
  end

  test "windows to the most recent MESSAGE_WINDOW messages, starting on a user turn" do
    # Build well past the window: alternating user/assistant pairs.
    30.times do |i|
      @chat.messages.create!(role: :assistant, content: "a#{i}")
      @chat.messages.create!(role: :user, content: "u#{i}", trainer: @user)
    end

    selection = @chat.messages_for_llm
    assert_operator selection.size, :<=, Agent::Chat::MessageSelection::MESSAGE_WINDOW
    assert_equal "user", selection.first.role.to_s, "first sent message must be a user turn"
    assert_equal "u29", selection.last.content, "must keep the most recent messages"
    assert_operator @chat.messages.count, :>, Agent::Chat::MessageSelection::MESSAGE_WINDOW,
      "the full history is still persisted"
  end

  test "drops leading non-user rows so the payload always starts with a user turn" do
    # A history that somehow begins with an assistant row (e.g. the very first
    # user message was empty debris and got dropped).
    @first_user.update_columns(content: "")
    @chat.messages.create!(role: :assistant, content: "sou eu primeiro")
    @chat.messages.create!(role: :user, content: "agora sim", trainer: @user)

    assert_equal "user", @chat.messages_for_llm.first.role.to_s
    assert_equal [ [ "user", "agora sim" ] ], selected
  end
end
