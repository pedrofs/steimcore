require "test_helper"

class Agent::Chat::RunnableTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @chat = @student.create_agent_chat!(
      organization: @organization,
      state: :running,
      model: StudentAgent.chat_kwargs[:model]
    )
    @user_message = @chat.messages.create!(role: :user, content: "Olá", trainer: @user)
  end

  test "successful turn broadcasts chunks + turn_completed and resets state to idle" do
    behavior = ->(chat, &block) {
      block&.call(double_chunk("Olá "))
      block&.call(double_chunk("treinador."))
      chat.messages.create!(role: :assistant, content: "Olá treinador.")
    }

    payloads = capture_broadcasts(@chat.stream_name) do
      stub_agent_new(behavior) { @chat.run_turn! }
    end

    assert_equal "idle", @chat.reload.state
    types = payloads.map { |p| p["type"] }
    assert_includes types, "chunk"
    assert_includes types, "turn_completed"
    chunk_deltas = payloads.select { |p| p["type"] == "chunk" }.map { |p| p["delta"] }
    assert_equal [ "Olá ", "treinador." ], chunk_deltas
    completed = payloads.find { |p| p["type"] == "turn_completed" }
    final_id = @chat.messages.where(role: :assistant).order(:created_at).last.id
    assert_equal final_id, completed["message_id"]
  end

  test "exception during complete broadcasts turn_failed, re-raises, and resets state via ensure" do
    behavior = ->(_chat, &_block) { raise RuntimeError, "Anthropic indisponível" }

    payloads = capture_broadcasts(@chat.stream_name) do
      stub_agent_new(behavior) do
        assert_raises(RuntimeError) { @chat.run_turn! }
      end
    end

    assert_equal "idle", @chat.reload.state
    failed = payloads.find { |p| p["type"] == "turn_failed" }
    refute_nil failed
    assert_equal "Anthropic indisponível", failed["error"]
  end

  test "MaxIterationsExceeded persists apology + broadcasts turn_failed without re-raising" do
    behavior = ->(_chat, &_block) { raise Agent::MaxIterationsExceeded }

    payloads = capture_broadcasts(@chat.stream_name) do
      stub_agent_new(behavior) { @chat.run_turn! }
    end

    apology = @chat.messages.where(role: :assistant).order(:created_at).last
    assert_match(/Desculpe/, apology.content)
    assert_equal "idle", @chat.reload.state
    failed = payloads.find { |p| p["type"] == "turn_failed" }
    refute_nil failed
    assert_equal "Limite de iterações excedido.", failed["error"]
  end

  test "run_turn! transcribes the latest user message's voice clips before invoking the agent" do
    @user_message.voice_clips.attach(
      io: StringIO.new("fake-audio-bytes"),
      filename: "clip.webm",
      content_type: "audio/webm"
    )

    transcribe_called_before_complete = false
    complete_called = false

    behavior = ->(chat, &_block) {
      complete_called = true
      assert transcribe_called_before_complete, "expected transcribe_voice_clips! to run before complete"
      chat.messages.create!(role: :assistant, content: "ok")
    }

    fake = ->(_path, **_kwargs) {
      transcribe_called_before_complete = true
      Struct.new(:text).new("transcrição")
    }

    RubyLLM.stub(:transcribe, fake) do
      stub_agent_new(behavior) { @chat.run_turn! }
    end

    assert complete_called
    assert_includes @user_message.reload.content, "transcrição"
  end

  test "run_turn! maps UnsupportedAttachmentError to a Portuguese friendly message" do
    behavior = ->(_chat, &_block) { raise RubyLLM::UnsupportedAttachmentError, "audio/webm" }

    payloads = capture_broadcasts(@chat.stream_name) do
      stub_agent_new(behavior) do
        assert_raises(RubyLLM::UnsupportedAttachmentError) { @chat.run_turn! }
      end
    end

    failed = payloads.find { |p| p["type"] == "turn_failed" }
    refute_nil failed
    assert_equal "Tipo de anexo não suportado pelo assistente.", failed["error"]
  end

  test "heal_history! destroys user messages with no content and no attachments" do
    @chat.messages.create!(role: :user, content: "", trainer: @user)
    @chat.messages.create!(role: :assistant, content: "Olá!")

    assert_difference -> { @chat.messages.where(role: :user, content: "").count }, -1 do
      @chat.heal_history!
    end
  end

  test "heal_history! preserves an empty user message that still has voice clips attached" do
    empty_with_clip = @chat.messages.create!(role: :user, content: "", trainer: @user)
    empty_with_clip.voice_clips.attach(
      io: StringIO.new("audio"), filename: "c.webm", content_type: "audio/webm"
    )

    assert_no_difference -> { @chat.messages.count } do
      @chat.heal_history!
    end
  end

  test "heal_history! coalesces a run of consecutive user messages into the latest one" do
    @chat.messages.create!(role: :assistant, content: "Pode mandar")
    a = @chat.messages.create!(role: :user, content: "primeira",  trainer: @user)
    b = @chat.messages.create!(role: :user, content: "segunda",   trainer: @user)
    c = @chat.messages.create!(role: :user, content: "terceira",  trainer: @user)

    @chat.heal_history!

    assert_raises(ActiveRecord::RecordNotFound) { a.reload }
    assert_raises(ActiveRecord::RecordNotFound) { b.reload }
    # @user_message (set up in `setup`) was the only user before this run, so
    # it's separated from a/b/c by the assistant turn and not part of the run.
    keeper = c.reload
    assert_equal "primeira\n\nsegunda\n\nterceira", keeper.content
  end

  test "heal_history! moves attachments from earlier user messages onto the keeper" do
    @chat.messages.create!(role: :assistant, content: "ok")
    earlier = @chat.messages.create!(role: :user, content: "",  trainer: @user)
    earlier.voice_clips.attach(
      io: StringIO.new("audio"), filename: "c.webm", content_type: "audio/webm"
    )
    keeper = @chat.messages.create!(role: :user, content: "depois", trainer: @user)

    @chat.heal_history!

    assert_raises(ActiveRecord::RecordNotFound) { earlier.reload }
    keeper.reload
    assert keeper.voice_clips.attached?
    assert_equal "depois", keeper.content
  end

  test "heal_history! backfills a synthetic tool result for an orphan assistant tool_use" do
    assistant = @chat.messages.create!(role: :assistant, content: "")
    orphan_tc = assistant.tool_calls.create!(tool_call_id: "toolu_orphan", name: "update_anamnesis", arguments: {})

    assert_nil orphan_tc.result_message

    assert_difference -> { @chat.messages.where(role: :tool).count }, +1 do
      @chat.heal_history!
    end

    backfilled = orphan_tc.reload.result_message
    refute_nil backfilled
    assert_equal Agent::Chat::Runnable::ORPHAN_TOOL_RESULT_NOTICE, backfilled.content
  end

  test "heal_history! is a no-op on a clean history" do
    @chat.messages.create!(role: :assistant, content: "Olá!")

    assert_no_difference -> { @chat.messages.count } do
      @chat.heal_history!
    end
  end

  test "run_turn! heals history before invoking the agent so the complete call sees alternating roles" do
    # Reproduce the broken-chat shape: an extra empty user + one trailing
    # duplicate user, on top of the user message created in setup.
    @chat.messages.create!(role: :user, content: "",       trainer: @user)
    @chat.messages.create!(role: :user, content: "extra",  trainer: @user)

    seen_roles = nil
    behavior = ->(chat, &_block) {
      seen_roles = chat.messages.order(:created_at, :id).pluck(:role)
      chat.messages.create!(role: :assistant, content: "ok")
    }

    stub_agent_new(behavior) { @chat.run_turn! }

    assert_equal [ "user" ], seen_roles, "expected heal_history! to collapse the user run before complete"
    user_rows = @chat.reload.messages.where(role: :user).order(:created_at).to_a
    assert_equal 1, user_rows.size
    assert_equal "Olá\n\nextra", user_rows.first.content
  end

  test "broadcast helpers emit tool_call_started and tool_call_completed with the documented payload shape" do
    payloads = capture_broadcasts(@chat.stream_name) do
      @chat.broadcast_tool_call_started!(tool_call_id: "toolu_123", name: "update_anamnesis", message_id: @user_message.id)
      @chat.broadcast_tool_call_completed!(tool_call_id: "toolu_123", result: { ok: true, summary_md: "Anamnese atualizada" })
    end

    started = payloads.find { |p| p["type"] == "tool_call_started" }
    assert_equal "toolu_123", started["tool_call_id"]
    assert_equal "update_anamnesis", started["name"]

    completed = payloads.find { |p| p["type"] == "tool_call_completed" }
    assert_equal "toolu_123", completed["tool_call_id"]
    assert_equal({ "ok" => true, "summary_md" => "Anamnese atualizada" }, completed["result"])
  end

  private
    def stub_agent_new(behavior)
      chat = @chat
      fake = Object.new
      fake.define_singleton_method(:complete) do |&streaming|
        behavior.call(chat, &streaming)
      end

      StudentAgent.define_singleton_method(:new) { |**_kwargs| fake }
      begin
        yield
      ensure
        StudentAgent.singleton_class.send(:remove_method, :new)
      end
    end

    def double_chunk(text)
      Struct.new(:content).new(text)
    end
end
