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
