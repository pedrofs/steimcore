require "test_helper"

class Organization::PrintQueueTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @organization.students.destroy_all
    @trainer = users(:one)
  end

  test "returns zero count and empty rows when the organization has no students" do
    payload = Organization::PrintQueue.new(@organization).to_h

    assert_equal 0, payload[:count]
    assert_equal [], payload[:rows]
  end

  test "lists an active periodization whose current version is completed and unprinted" do
    student = ready_to_print_student!("Pronto", anamnesis: "ok")

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_equal 1, payload[:count]
    assert_equal 1, payload[:rows].length
    row = payload[:rows].first
    assert_equal student.id, row[:student][:id]
    assert_equal "Pronto", row[:student][:name]
    assert_equal student.active_periodization.id, row[:periodization][:id]
    assert_equal student.active_periodization.current_version_id, row[:version][:id]
    assert_kind_of Time, row[:version][:created_at]
  end

  test "excludes periodizations whose current version is still pending" do
    student = @organization.students.create!(name: "Generating", anamnesis_md: "ok")
    student.start_periodization!(trainer: @trainer)
    # Version is in :generating, never completed → not promoted; current_version nil.

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_equal 0, payload[:count]
    assert_equal [], payload[:rows]
  end

  test "excludes periodizations whose current version is not completed" do
    student = @organization.students.create!(name: "Failed", anamnesis_md: "ok")
    version = student.start_periodization!(trainer: @trainer)
    version.complete!
    student.active_periodization.set_current_version!(version)
    # Force a non-completed status on the current_version to assert PrintQueue's
    # status guard, sidestepping the normal transition graph.
    version.update_columns(status: "failed")

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_equal 0, payload[:count]
    refute_includes payload[:rows].map { |r| r[:student][:id] }, student.id
  end

  test "excludes periodizations whose current version has already been printed" do
    student = ready_to_print_student!("Já impresso", anamnesis: "ok")
    student.active_periodization.current_version.mark_printed!

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_equal 0, payload[:count]
    assert_equal [], payload[:rows]
  end

  test "excludes archived periodizations" do
    student = ready_to_print_student!("Arquivado", anamnesis: "ok")
    student.active_periodization.archive!

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_equal 0, payload[:count]
    assert_equal [], payload[:rows]
  end

  test "excludes students flagged in plan_needs_action" do
    student = ready_to_print_student!("Plano falhou", anamnesis: "ok")
    # Add a failed version on the same active periodization to flag plan_needs_action.
    failed = student.active_periodization.versions.create!(trainer: @trainer)
    failed.transition_to!(:generating)
    failed.fail!("oops")

    assert_includes Organization::DashboardQueue.tagged_student_ids(@organization), student.id
    payload = Organization::PrintQueue.new(@organization).to_h

    refute_includes payload[:rows].map { |r| r[:student][:id] }, student.id
    assert_equal 0, payload[:count]
  end

  test "excludes students flagged in inactive" do
    travel_to Time.zone.local(2026, 5, 15, 10, 0, 0) do
      student = @organization.students.create!(name: "Inativo", anamnesis_md: "ok", weekly_frequency: 3)
      version = student.start_periodization!(trainer: @trainer)
      version.complete!
      student.active_periodization.set_current_version!(version)
      version.update_columns(created_at: 30.days.ago, updated_at: 30.days.ago)

      assert_includes Organization::DashboardQueue.tagged_student_ids(@organization), student.id
      payload = Organization::PrintQueue.new(@organization).to_h

      refute_includes payload[:rows].map { |r| r[:student][:id] }, student.id
    end
  end

  test "excludes students flagged in no_plan" do
    # no_plan = unarchived, active_periodization_id NULL. Such a student has no
    # current_version, so they're already absent from PrintQueue by the
    # `current_version_id IS NOT NULL` filter. This test just nails that down.
    student = @organization.students.create!(name: "Sem plano", anamnesis_md: "ok")
    assert_includes Organization::DashboardQueue.tagged_student_ids(@organization), student.id

    payload = Organization::PrintQueue.new(@organization).to_h

    refute_includes payload[:rows].map { |r| r[:student][:id] }, student.id
  end

  test "excludes students flagged in anamnesis_pending" do
    # Promoted plan but blank anamnesis: matches anamnesis_pending and also
    # would otherwise be eligible for the print queue.
    student = @organization.students.create!(name: "Sem anamnese")
    version = student.start_periodization!(trainer: @trainer)
    version.complete!
    student.active_periodization.set_current_version!(version)

    assert_includes Organization::DashboardQueue.tagged_student_ids(@organization), student.id
    payload = Organization::PrintQueue.new(@organization).to_h

    refute_includes payload[:rows].map { |r| r[:student][:id] }, student.id
  end

  test "excludes students matching multiple dashboard tags at once" do
    # No anamnesis + no plan = both no_plan and anamnesis_pending. Even with no
    # periodization they shouldn't appear, but the point is the union covers
    # both flags.
    student = @organization.students.create!(name: "Multi")

    payload = Organization::PrintQueue.new(@organization).to_h

    refute_includes payload[:rows].map { |r| r[:student][:id] }, student.id
  end

  test "count reflects every eligible periodization, rows are capped at 10" do
    12.times { |i| ready_to_print_student!("Pronto #{i}", anamnesis: "ok") }

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_equal 12, payload[:count]
    assert_equal 10, payload[:rows].length
  end

  test "rows are ordered oldest current_version first" do
    # All three students are recent enough to avoid the inactive cutoff, and
    # their anamnesis is filled in, so they stay eligible for the print queue.
    @newest = ready_to_print_student!("Newest", anamnesis: "ok")
    @newest.active_periodization.current_version.update_columns(created_at: 2.hours.ago)
    @oldest = ready_to_print_student!("Oldest", anamnesis: "ok")
    @oldest.active_periodization.current_version.update_columns(created_at: 6.hours.ago)
    @middle = ready_to_print_student!("Middle", anamnesis: "ok")
    @middle.active_periodization.current_version.update_columns(created_at: 4.hours.ago)

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_equal [ @oldest.id, @middle.id, @newest.id ],
                 payload[:rows].map { |r| r[:student][:id] }
  end

  test "is scoped to the given organization" do
    other_org = Organization.create!(name: "Outro")
    other_student = other_org.students.create!(name: "Externo", anamnesis_md: "ok")
    v = other_student.start_periodization!(trainer: @trainer)
    v.complete!
    other_student.active_periodization.set_current_version!(v)

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_equal 0, payload[:count]
    assert_equal [], payload[:rows]
  end

  private
    # Promotes a completed unprinted current version for a fresh student with
    # an anamnesis filled in so the student is NOT flagged by any of the four
    # dashboard tags (=> eligible for the print queue).
    def ready_to_print_student!(name, anamnesis:)
      student = @organization.students.create!(name: name, anamnesis_md: anamnesis)
      version = student.start_periodization!(trainer: @trainer)
      version.complete!
      student.active_periodization.set_current_version!(version)
      student.reload
    end
end
