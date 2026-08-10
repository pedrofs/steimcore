require "test_helper"

# The instructions template is re-rendered on every turn, so a nil in it breaks
# the whole conversation. These cover the volatile periodization section.
class StudentAgentTest < ActiveSupport::TestCase
  setup do
    @trainer = users(:one)
    @organization = @trainer.organization
    @student = @organization.students.create!(name: "Ana Prompt", weekly_frequency: 3)
  end

  test "renders the active periodization's dose and progress" do
    version = @student.start_periodization!(trainer: @trainer)
    version.periodization_length_weeks = 4  # target 4 * 3 = 12
    version.complete!
    @student.active_periodization.set_current_version!(version)
    session = TrainingSession.create!(
      student: @student, trainer: @trainer, periodization_version: version,
      workout_name_snapshot: "Treino A", workout_position_snapshot: 1,
      blocks_snapshot: [], progress: []
    )
    session.update_columns(finished_at: Time.current)

    prompt = render_instructions

    assert_match(/Duração planejada: 4 semanas/, prompt)
    assert_match(/Progresso: 1 de 12 sessões concluídas \(11 restantes\)/, prompt)
  end

  test "renders without a progress line when the student has no periodization" do
    prompt = render_instructions

    assert_match(/\(sem periodização ativa\)/, prompt)
    assert_no_match(/Progresso:/, prompt)
  end

  private
    def render_instructions
      chat = @student.find_or_create_agent_chat!
      StudentAgent.render_prompt(
        :instructions,
        chat: chat,
        inputs: { student: @student.reload, trainer: @trainer, chat: chat },
        locals: {}
      )
    end
end
