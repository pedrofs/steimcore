require "test_helper"

class Agent::Tools::ReadOrganizationNotesTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @trainer = users(:one)
    @tool = Agent::Tools::ReadOrganizationNotes.new(organization: @organization, trainer: @trainer)
  end

  test "returns the current notes_md" do
    @organization.update!(notes_md: "- Sessões de no máximo 1 hora")

    assert_equal({ notes_md: "- Sessões de no máximo 1 hora" }, @tool.execute)
  end

  test "returns an empty string when memory is empty" do
    @organization.update!(notes_md: "")

    assert_equal({ notes_md: "" }, @tool.execute)
  end

  test "reloads so a stale in-memory copy never leaks" do
    @organization.update!(notes_md: "antigo")
    # Simulate the system-prompt snapshot drifting from what's persisted:
    # the tool's record holds a stale value, the database holds the new one.
    Organization.where(id: @organization.id).update_all(notes_md: "novo")
    @organization.notes_md = "antigo"

    assert_equal({ notes_md: "novo" }, @tool.execute)
  end

  test "exposes the gem-normalized name" do
    assert_equal "read_organization_notes", @tool.name
  end
end
