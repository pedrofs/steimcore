require "test_helper"

class Agent::Chat::BriefableTest < ActiveSupport::TestCase
  setup do
    @trainer = users(:one)
    @organization = @trainer.organization
    @student = @organization.students.create!(name: "Ana Renovação", weekly_frequency: 3)
    @chat = @student.create_agent_chat!(
      organization: @organization,
      model: StudentAgent.chat_kwargs[:model]
    )
  end

  test "brief_new_periodization! persists a trainer message and flips the chat to running" do
    message = nil

    assert_difference -> { @chat.messages.count }, 1 do
      message = @chat.brief_new_periodization!(trainer: @trainer)
    end

    assert_equal "user", message.role
    assert_equal @trainer, message.trainer
    assert_equal "running", @chat.reload.state
  end

  test "briefing asks for questions before the plan when the student has no periodization" do
    content = @chat.brief_new_periodization!(trainer: @trainer).content

    assert_match(/primeira periodização para Ana Renovação/, content)
    assert_match(/perguntas necessárias/, content)
    assert_no_match(/sessões concluídas/, content)
  end

  test "briefing states the current block's dose and what is left of it" do
    promote_version(length_weeks: 4)  # target = 4 weeks * 3 sessions = 12
    finish_sessions(10)

    content = @chat.brief_new_periodization!(trainer: @trainer).content

    assert_match(/substituindo a atual/, content)
    assert_match(/bloco de 4 semanas/, content)
    assert_match(/10 de 12 sessões concluídas, faltam 2 sessões/, content)
  end

  test "briefing reports the overshoot when the student is past the planned dose" do
    promote_version(length_weeks: 4)
    finish_sessions(13)

    content = @chat.brief_new_periodization!(trainer: @trainer).content

    assert_match(/13 de 12 sessões concluídas, já passou 1 sessão do previsto/, content)
  end

  test "briefing omits the dose when the active periodization has no planned length" do
    @student.start_periodization!(trainer: @trainer)  # draft: no current_version, no length

    content = @chat.brief_new_periodization!(trainer: @trainer).content

    assert_match(/substituindo a atual/, content)
    assert_no_match(/bloco de/, content)
  end

  private
    def promote_version(length_weeks:)
      version = @student.start_periodization!(trainer: @trainer)
      version.periodization_length_weeks = length_weeks
      version.complete!
      @student.active_periodization.set_current_version!(version)
      @student.reload
      version
    end

    def finish_sessions(count)
      version = @student.active_periodization.current_version
      count.times do
        session = TrainingSession.create!(
          student: @student, trainer: @trainer, periodization_version: version,
          workout_name_snapshot: "Treino A", workout_position_snapshot: 1,
          blocks_snapshot: [], progress: []
        )
        session.update_columns(finished_at: Time.current)
      end
    end
end
