require "test_helper"

class Agent::Tools::ReadStudentNotesTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
    @trainer = users(:one)
    @tool = Agent::Tools::ReadStudentNotes.new(student: @student, trainer: @trainer)
  end

  test "returns the current notes_md" do
    @student.update!(notes_md: "- Sessão até 50 min\n- Sem impacto")

    assert_equal({ notes_md: "- Sessão até 50 min\n- Sem impacto" }, @tool.execute)
  end

  test "returns an empty string when memory is empty" do
    @student.update!(notes_md: "")

    assert_equal({ notes_md: "" }, @tool.execute)
  end

  test "reloads so a stale in-memory copy never leaks" do
    @student.update!(notes_md: "antigo")
    # Simulate the system-prompt snapshot drifting from what's persisted:
    # the tool's record holds a stale value, the database holds the new one.
    Student.where(id: @student.id).update_all(notes_md: "novo")
    @student.notes_md = "antigo"

    assert_equal({ notes_md: "novo" }, @tool.execute)
  end

  test "exposes the gem-normalized name" do
    assert_equal "read_student_notes", @tool.name
  end
end
