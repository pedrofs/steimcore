require "test_helper"

class Agent::Tools::UpdateStudentNotesTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
    @trainer = users(:one)
    @student.update!(notes_md: "")
    @tool = Agent::Tools::UpdateStudentNotes.new(student: @student, trainer: @trainer)
  end

  test "initializes empty notes with new_string when old_string is empty" do
    result = @tool.execute(
      old_string: "",
      new_string: "- Manter sessões em até 50 min",
      summary_md: "Adicionada regra de duração."
    )

    @student.reload
    assert_equal "- Manter sessões em até 50 min", @student.notes_md
    assert_equal({ ok: true, summary_md: "Adicionada regra de duração." }, result)
  end

  test "performs a surgical replace on existing notes" do
    @student.update!(notes_md: "- Sessão até 1h\n- Sem impacto")

    result = @tool.execute(
      old_string: "- Sessão até 1h",
      new_string: "- Sessão até 50 min",
      summary_md: "Reduziu duração."
    )

    @student.reload
    assert_equal "- Sessão até 50 min\n- Sem impacto", @student.notes_md
    assert result[:ok]
  end

  test "bubbles up editor errors without writing" do
    @student.update!(notes_md: "- Regra existente")

    result = @tool.execute(old_string: "regra inexistente", new_string: "x", summary_md: "Tentativa.")

    @student.reload
    assert_equal "- Regra existente", @student.notes_md
    assert_match(/não foi encontrado/i, result[:error])
  end

  test "requires summary_md" do
    result = @tool.execute(old_string: "", new_string: "x", summary_md: "  ")

    @student.reload
    assert_equal "", @student.notes_md
    assert_match(/resumo curto/i, result[:error])
  end

  test "exposes the gem-normalized name" do
    assert_equal "update_student_notes", @tool.name
  end
end
