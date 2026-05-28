require "test_helper"

class PeriodizationVersionTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    @periodization = @student.periodizations.create!
  end

  test "starts in :generating once a transition is invoked from :pending" do
    version = build_version

    assert_equal "pending", version.status

    version.transition_to!(:generating)

    assert_equal "generating", version.reload.status
  end

  test "rejects skipping straight from :pending to :completed" do
    version = build_version
    version.status = "completed"

    assert_not version.valid?
    assert_includes version.errors[:status].join, "cannot transition"
  end

  test "fail! requires an error_message and lands in :failed" do
    version = build_version
    version.transition_to!(:generating)

    version.fail!("Anthropic indisponível")

    assert_equal "failed", version.reload.status
    assert_equal "Anthropic indisponível", version.error_message
  end

  test "promoted? is true once the periodization points at this version" do
    version = build_version
    assert_not version.promoted?

    @periodization.update!(current_version: version)

    assert version.reload.promoted?
  end

  test "complete! transitions the version to :completed" do
    version = build_version(periodization_length_weeks: 8)
    version.transition_to!(:generating)

    version.complete!

    assert_equal "completed", version.reload.status
  end

  test "cannot transition to :completed while periodization_length_weeks is null" do
    version = build_version
    version.transition_to!(:generating)

    assert_raises(ActiveRecord::RecordInvalid) { version.complete! }
    assert_not version.valid?
    assert_includes version.errors[:periodization_length_weeks].join, "can't be blank"
    assert_equal "generating", version.reload.status
  end

  test "can move through pending → generating → failed without a length" do
    version = build_version
    assert_nil version.periodization_length_weeks

    version.transition_to!(:generating)
    version.fail!("Anthropic indisponível")

    assert_equal "failed", version.reload.status
  end

  test "a completed version with a periodization_length_weeks is valid" do
    version = build_version(periodization_length_weeks: 12)
    version.transition_to!(:generating)
    version.complete!

    assert version.reload.valid?
    assert_equal 12, version.periodization_length_weeks
  end

  private
    def build_version(periodization_length_weeks: nil)
      @periodization.versions.create!(
        trainer: @trainer,
        parent_version: nil,
        periodization_length_weeks: periodization_length_weeks
      )
    end
end
