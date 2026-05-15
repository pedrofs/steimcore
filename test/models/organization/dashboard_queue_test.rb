require "test_helper"

class Organization::DashboardQueueTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @organization.students.destroy_all
  end

  test "returns zero counts and empty rows when the organization has no students" do
    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal({ anamnesis_pending: 0 }, payload[:counts])
    assert_equal [], payload[:rows]
  end

  test "returns zero counts and empty rows when no student matches any tag" do
    @organization.students.create!(name: "Filled", anamnesis_md: "## Histórico\nLesão antiga.")

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal 0, payload[:counts][:anamnesis_pending]
    assert_equal [], payload[:rows]
  end

  test "anamnesis_pending count reflects every matching student in the org, not the row cap" do
    12.times { |i| @organization.students.create!(name: "Pending #{i}") }

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal 12, payload[:counts][:anamnesis_pending]
  end

  test "rows are capped at 10 even when more students match" do
    12.times { |i| @organization.students.create!(name: "Pending #{i}") }

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal 10, payload[:rows].length
  end

  test "each row carries the student summary and the anamnesis_pending tag" do
    student = @organization.students.create!(name: "Solo")

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal 1, payload[:rows].length
    row = payload[:rows].first
    assert_equal student.id, row[:student][:id]
    assert_equal "Solo", row[:student][:name]
    assert_equal [ :anamnesis_pending ], row[:tags]
    assert_equal :anamnesis_pending, row[:primary_tag]
  end

  test "deduplicates rows by student id" do
    student = @organization.students.create!(name: "Solo")
    # Slice 1 only has one tag, so dedup is trivially exercised — the same student
    # is included once even if multiple cohort scopes were to match.
    payload = Organization::DashboardQueue.new(@organization).to_h

    student_ids = payload[:rows].map { |r| r[:student][:id] }
    assert_equal [ student.id ], student_ids
    assert_equal student_ids.uniq, student_ids
  end

  test "excludes archived students from both counts and rows" do
    @organization.students.create!(name: "Active")
    @organization.students.create!(name: "Archived", archived_at: 1.day.ago)

    payload = Organization::DashboardQueue.new(@organization).to_h

    names = payload[:rows].map { |r| r[:student][:name] }
    assert_includes names, "Active"
    assert_not_includes names, "Archived"
    assert_equal 1, payload[:counts][:anamnesis_pending]
  end

  test "anamnesis_pending tiebreaker sorts oldest student.created_at first" do
    travel_to Time.zone.local(2026, 5, 1, 9, 0, 0) do
      @first = @organization.students.create!(name: "First")
    end
    travel_to Time.zone.local(2026, 5, 2, 9, 0, 0) do
      @second = @organization.students.create!(name: "Second")
    end
    travel_to Time.zone.local(2026, 5, 3, 9, 0, 0) do
      @third = @organization.students.create!(name: "Third")
    end

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal [ @first.id, @second.id, @third.id ],
                 payload[:rows].map { |r| r[:student][:id] }
  end

  test "is scoped to the given organization and ignores other orgs' students" do
    other_org = Organization.create!(name: "Outro")
    other_org.students.create!(name: "Externo")

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal 0, payload[:counts][:anamnesis_pending]
    assert_equal [], payload[:rows]
  end
end
