require "test_helper"

class Agent::Tools::UpdateStudentTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    @tool = Agent::Tools::UpdateStudent.new(student: @student, trainer: @trainer)
  end

  test "updates the structured fields passed in the call" do
    result = @tool.execute(
      birthday: "1992-05-17",
      sex: "Feminino",
      primary_goal: "Hipertrofia",
      weekly_frequency: 4,
      phone: "(11) 99999-0000",
      email: "alice@example.com",
      summary_md: "Cadastro inicial preenchido."
    )

    @student.reload
    assert_equal Date.new(1992, 5, 17), @student.birthday
    assert_equal "Feminino", @student.sex
    assert_equal "Hipertrofia", @student.primary_goal
    assert_equal 4, @student.weekly_frequency
    assert_equal "(11) 99999-0000", @student.phone
    assert_equal "alice@example.com", @student.email
    assert_equal true, result[:ok]
    assert_equal "Cadastro inicial preenchido.", result[:summary_md]
    assert_equal %w[birthday weekly_frequency sex primary_goal phone email].sort,
                 result[:updated_fields].sort
  end

  test "leaves untouched the fields that were not provided" do
    @student.update!(sex: "F", primary_goal: "Resistência", weekly_frequency: 3)

    result = @tool.execute(primary_goal: "Hipertrofia", summary_md: "Trocou objetivo.")

    @student.reload
    assert_equal "F", @student.sex
    assert_equal "Hipertrofia", @student.primary_goal
    assert_equal 3, @student.weekly_frequency
    assert_equal %w[primary_goal], result[:updated_fields]
  end

  test "empty string clears string fields and 0 clears weekly_frequency" do
    @student.update!(sex: "F", primary_goal: "Hipertrofia", weekly_frequency: 4, phone: "x", email: "x@y.z")

    @tool.execute(
      sex: "",
      primary_goal: "",
      weekly_frequency: 0,
      phone: "",
      email: "",
      summary_md: "Limpou cadastro."
    )

    @student.reload
    assert_nil @student.sex
    assert_nil @student.primary_goal
    assert_nil @student.weekly_frequency
    assert_nil @student.phone
    assert_nil @student.email
  end

  test "empty birthday clears the date" do
    @student.update!(birthday: Date.new(1990, 1, 1))

    @tool.execute(birthday: "", summary_md: "Limpou nascimento.")

    @student.reload
    assert_nil @student.birthday
  end

  test "rejects invalid birthday format and leaves the student untouched" do
    @student.update!(birthday: Date.new(1990, 1, 1))

    result = @tool.execute(birthday: "17/05/1992", summary_md: "Tenta inválido.")

    @student.reload
    assert_equal Date.new(1990, 1, 1), @student.birthday
    assert_match(/YYYY-MM-DD/, result[:error])
  end

  test "rejects weekly_frequency outside 0..7" do
    result = @tool.execute(weekly_frequency: 9, summary_md: "Tenta inválido.")

    assert_match(/entre 0 e 7/i, result[:error])
  end

  test "returns soft error when summary_md is blank" do
    result = @tool.execute(primary_goal: "Hipertrofia", summary_md: "  ")

    @student.reload
    assert_nil @student.primary_goal
    assert_match(/resumo curto/i, result[:error])
  end

  test "returns soft error when no fields were provided" do
    result = @tool.execute(summary_md: "qualquer")

    assert_match(/nenhum campo/i, result[:error])
  end

  test "tool exposes the gem-normalized name" do
    assert_equal "update_student", @tool.name
  end

  test "tool exposes schema with optional fields and required summary_md" do
    schema = @tool.params_schema

    assert_equal "object", schema["type"]
    assert_equal %w[summary_md], schema["required"]
    %w[birthday sex primary_goal weekly_frequency phone email summary_md].each do |field|
      assert_includes schema["properties"].keys, field
    end
  end
end
