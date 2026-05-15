require "test_helper"

class Agent::Message::TranscribableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
    @chat = @student.create_agent_chat!(
      organization: @organization,
      model: StudentAgent.chat_kwargs[:model]
    )
    @message = @chat.messages.create!(role: :user, content: "Veja", trainer: @user)
  end

  test "no-op when there are no voice_clips attached" do
    RubyLLM.stub(:transcribe, ->(*) { raise "should not be called" }) do
      assert_nothing_raised { @message.transcribe_voice_clips! }
    end
    assert_equal "Veja", @message.reload.content
  end

  test "transcribes each voice clip and bakes transcripts into content" do
    attach_voice_clip!(@message, "clip-a.webm")
    attach_voice_clip!(@message, "clip-b.webm")

    transcripts = [ "olá treinador", "preciso de ajuda" ]
    call_count = 0
    fake = ->(path, **kwargs) {
      assert_equal "pt", kwargs[:language]
      assert path.to_s.end_with?(".webm") || File.exist?(path.to_s)
      result = Struct.new(:text).new(transcripts[call_count])
      call_count += 1
      result
    }

    RubyLLM.stub(:transcribe, fake) do
      @message.transcribe_voice_clips!
    end

    assert_equal 2, call_count
    content = @message.reload.content
    assert_includes content, "Veja"
    assert_includes content, Agent::Message::Transcribable::TRANSCRIPT_HEADER
    assert_includes content, "olá treinador"
    assert_includes content, "preciso de ajuda"
  end

  test "caches transcript on blob metadata and skips re-transcription on a second call" do
    attach_voice_clip!(@message, "clip.webm")

    fake = ->(_path, **_kwargs) { Struct.new(:text).new("primeira") }
    RubyLLM.stub(:transcribe, fake) { @message.transcribe_voice_clips! }

    blob = @message.voice_clips.first.blob
    assert_equal "primeira", blob.reload.metadata["transcript"]

    refusing = ->(*) { raise "should not re-transcribe" }
    RubyLLM.stub(:transcribe, refusing) do
      assert_nothing_raised { @message.transcribe_voice_clips! }
    end
  end

  test "transcript header is appended even when message has no prior text content" do
    silent = @chat.messages.create!(role: :user, content: "", trainer: @user)
    attach_voice_clip!(silent, "clip.webm")

    fake = ->(_path, **_kwargs) { Struct.new(:text).new("transcrição única") }
    RubyLLM.stub(:transcribe, fake) { silent.transcribe_voice_clips! }

    content = silent.reload.content
    assert content.start_with?(Agent::Message::Transcribable::TRANSCRIPT_HEADER)
    assert_includes content, "transcrição única"
  end

  private
    def attach_voice_clip!(message, filename)
      message.voice_clips.attach(
        io: StringIO.new("fake-audio-bytes-#{filename}"),
        filename: filename,
        content_type: "audio/webm"
      )
    end
end
