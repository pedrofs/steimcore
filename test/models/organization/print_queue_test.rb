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
    version.periodization_length_weeks = 8
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

  test "includes students whose plan also needs trainer action" do
    student = ready_to_print_student!("Plano falhou", anamnesis: "ok")
    # Add a failed version on the same active periodization — the student is
    # also flagged plan_needs_action on the Dashboard queue, but Print queue
    # membership is independent.
    failed = student.active_periodization.versions.create!(trainer: @trainer)
    failed.transition_to!(:generating)
    failed.fail!("oops")

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_includes payload[:rows].map { |r| r[:student][:id] }, student.id
    assert_equal 1, payload[:count]
  end

  test "includes students flagged inactive" do
    travel_to Time.zone.local(2026, 5, 15, 10, 0, 0) do
      student = @organization.students.create!(name: "Inativo", anamnesis_md: "ok", weekly_frequency: 3)
      version = student.start_periodization!(trainer: @trainer)
      version.periodization_length_weeks = 8
      version.complete!
      student.active_periodization.set_current_version!(version)
      version.update_columns(created_at: 30.days.ago, updated_at: 30.days.ago)

      payload = Organization::PrintQueue.new(@organization).to_h

      assert_includes payload[:rows].map { |r| r[:student][:id] }, student.id
    end
  end

  test "excludes students with no active periodization" do
    # no_plan = unarchived, active_periodization_id NULL. Such a student has no
    # current_version, so they're absent from PrintQueue by the
    # `current_version_id IS NOT NULL` filter.
    student = @organization.students.create!(name: "Sem plano", anamnesis_md: "ok")

    payload = Organization::PrintQueue.new(@organization).to_h

    refute_includes payload[:rows].map { |r| r[:student][:id] }, student.id
  end

  test "includes students with a pending anamnesis" do
    student = @organization.students.create!(name: "Sem anamnese")
    version = student.start_periodization!(trainer: @trainer)
    version.periodization_length_weeks = 8
    version.complete!
    student.active_periodization.set_current_version!(version)

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_includes payload[:rows].map { |r| r[:student][:id] }, student.id
  end

  test "includes students flagged periodization_overdue" do
    # The plan was just promoted and is unprinted — the trainer still needs the
    # sheet on paper even though the student has trained past the target.
    student = @organization.students.create!(name: "Vencida", anamnesis_md: "ok", weekly_frequency: 1)
    version = student.start_periodization!(trainer: @trainer)
    version.periodization_length_weeks = 1 # target 1
    version.complete!
    student.active_periodization.set_current_version!(version)
    2.times do
      TrainingSession.create!(
        student: student, trainer: @trainer, periodization_version: version,
        workout_name_snapshot: "Treino A", workout_position_snapshot: 1,
        blocks_snapshot: [], progress: []
      ).update_columns(finished_at: Time.current)
    end

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_includes payload[:rows].map { |r| r[:student][:id] }, student.id
    assert_equal 1, payload[:count]
  end

  test "includes students flagged periodization_due" do
    # Same reasoning as periodization_overdue: the newly promoted current
    # version still needs to be handed to the student.
    student = @organization.students.create!(name: "Quase lá", anamnesis_md: "ok", weekly_frequency: 1)
    version = student.start_periodization!(trainer: @trainer)
    version.periodization_length_weeks = 8 # target 8
    version.complete!
    student.active_periodization.set_current_version!(version)
    6.times do
      TrainingSession.create!(
        student: student, trainer: @trainer, periodization_version: version,
        workout_name_snapshot: "Treino A", workout_position_snapshot: 1,
        blocks_snapshot: [], progress: []
      ).update_columns(finished_at: Time.current)
    end

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_includes payload[:rows].map { |r| r[:student][:id] }, student.id
    assert_equal 1, payload[:count]
  end

  test "excludes students without an active periodization regardless of other state" do
    # No anamnesis + no plan: still excluded because they have no current_version.
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
    v.periodization_length_weeks = 8
    v.complete!
    other_student.active_periodization.set_current_version!(v)

    payload = Organization::PrintQueue.new(@organization).to_h

    assert_equal 0, payload[:count]
    assert_equal [], payload[:rows]
  end

  private
    # Promotes a completed unprinted current version for a fresh student so
    # the row is eligible for the print queue.
    def ready_to_print_student!(name, anamnesis:)
      student = @organization.students.create!(name: name, anamnesis_md: anamnesis)
      version = student.start_periodization!(trainer: @trainer)
      version.periodization_length_weeks = 8
      version.complete!
      student.active_periodization.set_current_version!(version)
      student.reload
    end
end
