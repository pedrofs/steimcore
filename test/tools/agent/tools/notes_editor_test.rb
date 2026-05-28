require "test_helper"

class Agent::Tools::NotesEditorTest < ActiveSupport::TestCase
  test "initializes empty memory when old_string is also empty" do
    result = Agent::Tools::NotesEditor.apply(current: "", old_string: "", new_string: "Regra 1")

    assert result.ok?
    assert_equal "Regra 1", result.value
  end

  test "errors when memory is empty but old_string is provided" do
    result = Agent::Tools::NotesEditor.apply(current: "", old_string: "algo", new_string: "novo")

    assert_not result.ok?
    assert_match(/vazia/i, result.error)
  end

  test "errors when memory has content but old_string is empty" do
    result = Agent::Tools::NotesEditor.apply(current: "Regra existente", old_string: "", new_string: "Novo")

    assert_not result.ok?
    assert_match(/não pode ser vazio/i, result.error)
  end

  test "replaces a single unique occurrence" do
    current = "- Sessão até 1h\n- Sempre alongar no final"

    result = Agent::Tools::NotesEditor.apply(
      current:   current,
      old_string: "- Sessão até 1h",
      new_string: "- Sessão até 50 min"
    )

    assert result.ok?
    assert_equal "- Sessão até 50 min\n- Sempre alongar no final", result.value
  end

  test "allows empty new_string to delete a chunk" do
    current = "linha 1\nlinha 2\nlinha 3"

    result = Agent::Tools::NotesEditor.apply(current: current, old_string: "linha 2\n", new_string: "")

    assert result.ok?
    assert_equal "linha 1\nlinha 3", result.value
  end

  test "errors when old_string is not found" do
    result = Agent::Tools::NotesEditor.apply(current: "Regra A", old_string: "Regra Z", new_string: "x")

    assert_not result.ok?
    assert_match(/não foi encontrado/i, result.error)
  end

  test "errors when old_string is ambiguous" do
    current = "regra X\nregra X\nregra X"

    result = Agent::Tools::NotesEditor.apply(current: current, old_string: "regra X", new_string: "regra Y")

    assert_not result.ok?
    assert_match(/3 vezes/, result.error)
  end
end
