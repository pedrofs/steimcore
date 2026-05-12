require "test_helper"

class TrainingSession::FinishableTest < ActiveSupport::TestCase
  setup do
    @alice = students(:alice)
    @bob = students(:bob)
    @carol = students(:archived_carol)
    @trainer = users(:one)
  end

  test "finish! sets finished_at to a non-nil timestamp" do
    session = build_session(@alice)
    session.save!

    freeze_time = Time.current
    travel_to(freeze_time) { session.finish! }

    assert_not_nil session.reload.finished_at
    assert_in_delta freeze_time.to_f, session.finished_at.to_f, 1
  end

  test "reopen! nils finished_at" do
    session = build_session(@alice)
    session.save!
    session.update!(finished_at: 1.minute.ago)

    session.reopen!

    assert_nil session.reload.finished_at
  end

  test "active scope returns only sessions with finished_at IS NULL" do
    active = build_session(@alice)
    active.save!
    finished = build_session(@bob)
    finished.save!
    finished.update!(finished_at: Time.current)

    ids = TrainingSession.active.pluck(:id)
    assert_includes ids, active.id
    assert_not_includes ids, finished.id
  end

  test "finished scope returns only sessions with finished_at IS NOT NULL" do
    active = build_session(@alice)
    active.save!
    finished = build_session(@bob)
    finished.save!
    finished.update!(finished_at: Time.current)

    ids = TrainingSession.finished.pluck(:id)
    assert_includes ids, finished.id
    assert_not_includes ids, active.id
  end

  test "stale scope returns active sessions created more than STALE_CUTOFF ago" do
    fresh = build_session(@alice)
    fresh.save!
    fresh.update_columns(created_at: 1.hour.ago)

    stale = build_session(@bob)
    stale.save!
    stale.update_columns(created_at: 9.hours.ago)

    ids = TrainingSession.stale.pluck(:id)
    assert_includes ids, stale.id
    assert_not_includes ids, fresh.id
  end

  test "stale scope excludes finished sessions even if old" do
    old_finished = build_session(@alice)
    old_finished.save!
    old_finished.update_columns(created_at: 10.hours.ago)
    old_finished.update!(finished_at: Time.current)

    assert_empty TrainingSession.stale.where(id: old_finished.id)
  end

  test "stale scope cutoff boundary: exactly STALE_CUTOFF ago is not stale" do
    boundary = build_session(@alice)
    boundary.save!
    boundary.update_columns(created_at: TrainingSession::Finishable::STALE_CUTOFF.ago)

    travel(1.second) do
      assert_includes TrainingSession.stale.pluck(:id), boundary.id
    end
  end

  test "STALE_CUTOFF constant is defined as 8 hours" do
    assert_equal 8.hours, TrainingSession::Finishable::STALE_CUTOFF
  end

  private
    def build_session(student)
      TrainingSession.new(
        student: student,
        trainer: @trainer,
        workout_name_snapshot: "Treino #{student.name}",
        workout_position_snapshot: 1,
        blocks_snapshot: [],
        progress: []
      )
    end
end
