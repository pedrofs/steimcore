class AddAgentToolCallToPeriodizationVersions < ActiveRecord::Migration[8.2]
  def change
    add_reference :periodization_versions, :agent_tool_call,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :agent_tool_calls }
  end
end
