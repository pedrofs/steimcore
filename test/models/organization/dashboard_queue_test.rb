require "test_helper"

class Organization::DashboardQueueTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @organization.students.destroy_all
  end

  test "returns zero counts and empty rows when the organization has no students" do
    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal({ plan_needs_action: 0, no_plan: 0, anamnesis_pending: 0 }, payload[:counts])
    assert_equal [], payload[:rows]
  end

  test "returns zero counts and empty rows when no student matches any tag" do
    trainer = users(:one)
    student = @organization.students.create!(name: "Filled", anamnesis_md: "## Histórico\nLesão antiga.")
    version = student.start_periodization!(trainer: trainer)
    version.complete!
    student.active_periodization.set_current_version!(version)

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal 0, payload[:counts][:anamnesis_pending]
    assert_equal 0, payload[:counts][:no_plan]
    assert_equal 0, payload[:counts][:plan_needs_action]
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

  test "each row carries the student summary and only the tags it matches" do
    trainer = users(:one)
    student = @organization.students.create!(name: "Solo")
    student.start_periodization!(trainer: trainer) # has plan now, only anamnesis_pending applies

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal 1, payload[:rows].length
    row = payload[:rows].first
    assert_equal student.id, row[:student][:id]
    assert_equal "Solo", row[:student][:name]
    assert_equal [ :anamnesis_pending ], row[:tags]
    assert_equal :anamnesis_pending, row[:primary_tag]
  end

  test "deduplicates rows by student id when a student matches multiple tags" do
    # A fresh student has both no anamnesis AND no active plan, so they match
    # both cohorts and must appear as one row with stacked tags.
    student = @organization.students.create!(name: "Solo")

    payload = Organization::DashboardQueue.new(@organization).to_h

    student_ids = payload[:rows].map { |r| r[:student][:id] }
    assert_equal [ student.id ], student_ids
    assert_equal student_ids.uniq, student_ids
  end

  test "a student matching both no_plan and anamnesis_pending appears once with stacked tags, ordered by bottleneck-first priority" do
    student = @organization.students.create!(name: "Stacked")

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal 1, payload[:rows].length
    row = payload[:rows].first
    assert_equal student.id, row[:student][:id]
    assert_equal [ :no_plan, :anamnesis_pending ], row[:tags]
    assert_equal :no_plan, row[:primary_tag]
  end

  test "no_plan outranks anamnesis_pending — students matching no_plan sort before students matching only anamnesis_pending" do
    trainer = users(:one)
    travel_to Time.zone.local(2026, 5, 1, 9, 0, 0) do
      # Oldest student, but has a plan — only matches anamnesis_pending.
      @anamnesis_only = @organization.students.create!(name: "Anamnesis only")
      @anamnesis_only.start_periodization!(trainer: trainer)
    end
    travel_to Time.zone.local(2026, 5, 2, 9, 0, 0) do
      # Newer student, but matches no_plan (higher priority).
      @no_plan_with_anamnesis = @organization.students.create!(name: "No plan, has anamnesis", anamnesis_md: "## História\nx")
    end

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal [ @no_plan_with_anamnesis.id, @anamnesis_only.id ],
                 payload[:rows].map { |r| r[:student][:id] }
    assert_equal [ :no_plan, :anamnesis_pending ],
                 payload[:rows].map { |r| r[:primary_tag] }
  end

  test "no_plan count reflects every matching student in the org" do
    8.times { |i| @organization.students.create!(name: "Pending #{i}", anamnesis_md: "x") }

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal 8, payload[:counts][:no_plan]
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

  test "plan_needs_action outranks no_plan and anamnesis_pending — students matching plan_needs_action sort first" do
    trainer = users(:one)
    # A student matching plan_needs_action (has a failed version on active plan).
    plan_action = @organization.students.create!(name: "Plan action", anamnesis_md: "x")
    version = plan_action.start_periodization!(trainer: trainer)
    version.fail!("oops")
    # A student matching only no_plan.
    no_plan = @organization.students.create!(name: "No plan", anamnesis_md: "x")
    # A student matching only anamnesis_pending.
    anamnesis = @organization.students.create!(name: "Anamnesis only")
    anamnesis_version = anamnesis.start_periodization!(trainer: trainer)
    anamnesis_version.complete!
    anamnesis.active_periodization.set_current_version!(anamnesis_version)

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal [ plan_action.id, no_plan.id, anamnesis.id ],
                 payload[:rows].map { |r| r[:student][:id] }
    assert_equal [ :plan_needs_action, :no_plan, :anamnesis_pending ],
                 payload[:rows].map { |r| r[:primary_tag] }
  end

  test "plan_needs_action count reflects every matching student in the org" do
    trainer = users(:one)
    3.times do |i|
      student = @organization.students.create!(name: "Falhou #{i}", anamnesis_md: "x")
      version = student.start_periodization!(trainer: trainer)
      version.fail!("oops")
    end

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal 3, payload[:counts][:plan_needs_action]
  end

  test "plan_needs_action tiebreaker sorts by the oldest matching version's created_at ascending" do
    trainer = users(:one)

    travel_to Time.zone.local(2026, 5, 3, 9, 0, 0) do
      @newest = @organization.students.create!(name: "Newest action", anamnesis_md: "x")
      @newest.start_periodization!(trainer: trainer).fail!("oops")
    end
    travel_to Time.zone.local(2026, 5, 1, 9, 0, 0) do
      @oldest = @organization.students.create!(name: "Oldest action", anamnesis_md: "x")
      @oldest.start_periodization!(trainer: trainer).fail!("oops")
    end
    travel_to Time.zone.local(2026, 5, 2, 9, 0, 0) do
      @middle = @organization.students.create!(name: "Middle action", anamnesis_md: "x")
      @middle.start_periodization!(trainer: trainer).fail!("oops")
    end

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal [ @oldest.id, @middle.id, @newest.id ],
                 payload[:rows].map { |r| r[:student][:id] }
  end

  test "is scoped to the given organization and ignores other orgs' students" do
    other_org = Organization.create!(name: "Outro")
    other_org.students.create!(name: "Externo")

    payload = Organization::DashboardQueue.new(@organization).to_h

    assert_equal 0, payload[:counts][:anamnesis_pending]
    assert_equal 0, payload[:counts][:plan_needs_action]
    assert_equal [], payload[:rows]
  end
end
