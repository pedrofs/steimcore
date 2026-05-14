require "test_helper"

class Agent::Tools::CreatePeriodizationTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    @tool = Agent::Tools::CreatePeriodization.new(student: @student, trainer: @trainer)
  end

  test "happy path: creates a periodization with the supplied workouts and stamps the originating tool_call" do
    chat = @student.create_agent_chat!(organization: @organization)
    message = chat.messages.create!(role: :assistant, content: "ok")
    persisted_tool_call = Agent::ToolCall.create!(
      message: message,
      tool_call_id: "tc_abc123",
      name: "create_periodization",
      arguments: {}
    )
    @tool.current_tool_call_llm_id = persisted_tool_call.tool_call_id

    result = @tool.execute(
      body_md: "## Plano\n\nMesociclo base.",
      workouts: [
        { "name" => "A", "position" => 1, "blocks" => [ { "kind" => "exercise", "name" => "Agachamento", "prescription" => "4x8" } ] },
        { "name" => "B", "position" => 2, "blocks" => [ { "kind" => "exercise", "name" => "Supino", "prescription" => "4x8" } ] }
      ],
      summary_md: "Plano de hipertrofia 2x/sem."
    )

    @student.reload
    assert_not_nil @student.active_periodization
    current = @student.active_periodization.current_version
    assert_nil current, "newly-created periodization is in draft — current_version is nil until promotion"

    version = @student.active_periodization.versions.first
    assert_equal "completed", version.status
    assert_equal "## Plano\n\nMesociclo base.", version.body_md
    assert_equal %w[A B], version.workouts.order(:position).pluck(:name)
    assert_equal persisted_tool_call.id, version.agent_tool_call_id

    assert_equal true, result[:ok]
    assert_equal version.id, result[:version_id]
    assert_equal "create", result[:scope]
    assert_equal 2, result[:workout_count]
    assert_equal "Plano de hipertrofia 2x/sem.", result[:summary_md]
    assert_equal 1, result[:version_number]
  end

  test "soft-errors when the student already has an active periodization" do
    @student.update!(active_periodization: @student.periodizations.create!)

    result = @tool.execute(
      body_md: "ignored",
      workouts: [ { "name" => "A", "position" => 1, "blocks" => [ { "kind" => "exercise", "name" => "X", "prescription" => "3x5" } ] } ],
      summary_md: "qualquer"
    )

    assert_match(/já tem periodização ativa/i, result[:error])
    assert_equal 1, @student.periodizations.count
  end

  test "soft-errors when blocks fail Workout::Blocks validation, without persisting anything" do
    before_count = Periodization.count

    result = @tool.execute(
      body_md: "## Plano",
      workouts: [
        { "name" => "A", "position" => 1, "blocks" => [ { "kind" => "exercise", "name" => "Agachamento" } ] }
      ],
      summary_md: "x"
    )

    assert_match(/prescription/i, result[:error])
    assert_equal before_count, Periodization.count
  end

  test "soft-errors when summary_md is blank" do
    result = @tool.execute(
      body_md: "## Plano",
      workouts: [ { "name" => "A", "position" => 1, "blocks" => [ { "kind" => "exercise", "name" => "X", "prescription" => "3x5" } ] } ],
      summary_md: "   "
    )

    assert_match(/resumo curto/i, result[:error])
  end

  test "exposes the gem-normalized name and a raw JSON Schema with workouts as an object array" do
    assert_equal "create_periodization", @tool.name

    schema = @tool.params_schema
    assert_equal "object", schema["type"]
    assert_includes schema["required"], "body_md"
    assert_includes schema["required"], "workouts"
    assert_includes schema["required"], "summary_md"

    workout_schema = schema.dig("properties", "workouts", "items")
    assert_equal "object", workout_schema["type"], "workouts is an array of structured workout objects, not strings"
    assert_includes workout_schema["required"], "blocks"
  end
end
