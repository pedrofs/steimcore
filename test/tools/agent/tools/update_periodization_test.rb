require "test_helper"

class Agent::Tools::UpdatePeriodizationTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    @tool = Agent::Tools::UpdatePeriodization.new(student: @student, trainer: @trainer)
  end

  test "mutates an editable draft in place when current_version is not read-only" do
    version = seed_draft_periodization!

    result = @tool.execute(
      body_md: "## Plano revisado",
      workouts: [
        { "name" => "A", "position" => 1, "blocks" => [ { "kind" => "exercise", "name" => "Agachamento livre", "prescription" => "5x5" } ] }
      ],
      summary_md: "Foco em força."
    )

    version.reload
    assert_equal "## Plano revisado", version.body_md
    assert_equal "Agachamento livre", version.workouts.first.blocks.first["name"]
    assert_equal version.id, result[:version_id]
    assert_equal "periodization", result[:scope]
    assert_equal 1, result[:workout_count]
    assert_equal "Foco em força.", result[:summary_md]
    assert_equal 1, @student.active_periodization.versions.count, "no new version when the current draft is editable"
  end

  test "forks a new version when the current_version is read-only (promoted)" do
    version = seed_draft_periodization!
    version.periodization.set_current_version!(version)

    chat = @student.create_agent_chat!(organization: @organization)
    message = chat.messages.create!(role: :assistant, content: "ok")
    persisted_tool_call = Agent::ToolCall.create!(message: message, tool_call_id: "tc_upd", name: "update_periodization", arguments: {})
    @tool.current_tool_call_llm_id = persisted_tool_call.tool_call_id

    result = @tool.execute(
      body_md: "## Plano v2",
      workouts: [
        { "name" => "Push", "position" => 1, "blocks" => [ { "kind" => "exercise", "name" => "Supino", "prescription" => "5x5" } ] },
        { "name" => "Pull", "position" => 2, "blocks" => [ { "kind" => "exercise", "name" => "Remada", "prescription" => "5x5" } ] }
      ],
      summary_md: "Split push/pull."
    )

    assert_kind_of String, result[:version_id], "tool should return ok with version_id; got #{result.inspect}"
    assert_equal 2, @student.active_periodization.versions.reload.count
    new_version = PeriodizationVersion.find(result[:version_id])
    assert_equal "## Plano v2", new_version.body_md
    assert_equal version.id, new_version.parent_version_id
    assert_equal "completed", new_version.status
    assert_equal persisted_tool_call.id, new_version.agent_tool_call_id
    assert_equal 2, result[:workout_count]
    assert_equal 2, result[:version_number]
  end

  test "soft-errors when the student has no active periodization" do
    assert_nil @student.active_periodization

    result = @tool.execute(
      body_md: "x",
      workouts: [ { "name" => "A", "position" => 1, "blocks" => [ { "kind" => "exercise", "name" => "Supino", "prescription" => "3x5" } ] } ],
      summary_md: "x"
    )

    assert_match(/não tem periodização ativa/i, result[:error])
    assert_match(/create_periodization/, result[:error])
  end

  test "soft-errors on block schema violations without mutating the draft" do
    version = seed_draft_periodization!
    body_before = version.body_md

    result = @tool.execute(
      body_md: "## Plano destrutivo",
      workouts: [
        { "name" => "A", "position" => 1, "blocks" => [ { "kind" => "exercise", "name" => "Agachamento" } ] }
      ],
      summary_md: "x"
    )

    version.reload
    assert_match(/prescription/i, result[:error])
    assert_equal body_before, version.body_md, "draft must not be mutated when validation fails"
  end

  private
    def seed_draft_periodization!
      version = @student.start_periodization!(trainer: @trainer)
      version.fork_with!(
        scope: :create,
        patch: {
          body_md: "## Plano base",
          workouts: [
            { name: "A", position: 1, blocks: [ { kind: "exercise", name: "Agachamento", prescription: "4x8" } ] }
          ]
        },
        trainer: @trainer
      )
      version.complete!
      version.reload
    end
end
