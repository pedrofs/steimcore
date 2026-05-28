require "test_helper"

class Agent::Tools::UpdateOrganizationNotesTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @trainer = users(:one)
    @organization.update!(notes_md: "")
    @tool = Agent::Tools::UpdateOrganizationNotes.new(organization: @organization, trainer: @trainer)
  end

  test "initializes empty notes with new_string when old_string is empty" do
    result = @tool.execute(
      old_string: "",
      new_string: "- Sessões de no máximo 1 hora",
      summary_md: "Definida duração padrão."
    )

    @organization.reload
    assert_equal "- Sessões de no máximo 1 hora", @organization.notes_md
    assert_equal({ ok: true, summary_md: "Definida duração padrão." }, result)
  end

  test "performs a surgical replace on existing notes" do
    @organization.update!(notes_md: "- Sempre alongar no final\n- RPE em vez de %1RM")

    result = @tool.execute(
      old_string: "- Sempre alongar no final",
      new_string: "- Terminar com alongamentos de 5 min",
      summary_md: "Detalhou alongamento."
    )

    @organization.reload
    assert_equal "- Terminar com alongamentos de 5 min\n- RPE em vez de %1RM", @organization.notes_md
    assert result[:ok]
  end

  test "bubbles up editor errors without writing" do
    @organization.update!(notes_md: "- Regra geral")

    result = @tool.execute(old_string: "outra coisa", new_string: "x", summary_md: "Tentativa.")

    @organization.reload
    assert_equal "- Regra geral", @organization.notes_md
    assert_match(/não foi encontrado/i, result[:error])
  end

  test "requires summary_md" do
    result = @tool.execute(old_string: "", new_string: "x", summary_md: "  ")

    @organization.reload
    assert_equal "", @organization.notes_md
    assert_match(/resumo curto/i, result[:error])
  end

  test "exposes the gem-normalized name" do
    assert_equal "update_organization_notes", @tool.name
  end
end
