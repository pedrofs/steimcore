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
    version = build_version
    version.transition_to!(:generating)

    version.complete!

    assert_equal "completed", version.reload.status
  end

  private
    def build_version
      @periodization.versions.create!(
        trainer: @trainer,
        parent_version: nil
      )
    end
end
