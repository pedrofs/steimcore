require "test_helper"

class Agent::Tools::UpdateAnamnesisTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    @tool = Agent::Tools::UpdateAnamnesis.new(student: @student, trainer: @trainer)
  end

  test "commits new anamnesis_md and returns ok with summary_md" do
    new_md = "## Histórico\n\nLesão no joelho direito desde 2024."
    summary = "Adicionada lesão no joelho direito."

    result = @tool.execute(anamnesis_md: new_md, summary_md: summary)

    @student.reload
    assert_equal new_md, @student.anamnesis_md
    assert_equal({ ok: true, summary_md: summary }, result)
  end

  test "returns soft error when anamnesis_md is blank, leaves student untouched" do
    original = @student.anamnesis_md

    result = @tool.execute(anamnesis_md: "   ", summary_md: "any")

    @student.reload
    assert_equal original, @student.anamnesis_md
    assert_match(/em branco/i, result[:error])
  end

  test "returns soft error when summary_md is blank, leaves student untouched" do
    original = @student.anamnesis_md

    result = @tool.execute(anamnesis_md: "## Novo conteúdo", summary_md: "  ")

    @student.reload
    assert_equal original, @student.anamnesis_md
    assert_match(/resumo curto/i, result[:error])
  end

  test "tool exposes the gem-normalized name" do
    assert_equal "update_anamnesis", @tool.name
  end

  test "tool exposes description, parameters, and JSON schema" do
    assert_includes @tool.description.to_s.downcase, "anamnese"

    param_names = @tool.parameters.keys
    assert_includes param_names, :anamnesis_md
    assert_includes param_names, :summary_md

    schema = @tool.params_schema
    assert_equal "object", schema["type"]
    assert_equal %w[anamnesis_md summary_md].sort, schema["required"].sort
  end
end
