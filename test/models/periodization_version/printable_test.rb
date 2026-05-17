require "test_helper"

class PeriodizationVersion::PrintableTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
    @trainer = users(:one)
    @periodization = @student.periodizations.create!
    @version = @periodization.versions.create!(trainer: @trainer)
  end

  test "printed? is false on a fresh record" do
    assert_nil @version.printed_at
    assert_not @version.printed?
  end

  test "printed? is true once printed_at is set" do
    @version.update!(printed_at: Time.current)

    assert @version.printed?
  end

  test "mark_printed! sets printed_at to a recent time" do
    freeze_time do
      @version.mark_printed!

      assert_equal Time.current, @version.reload.printed_at
      assert @version.printed?
    end
  end

  test "mark_printed! is a no-op when the version is already printed" do
    original_printed_at = Time.zone.local(2026, 5, 1, 12, 0, 0)
    @version.update!(printed_at: original_printed_at)

    travel_to Time.zone.local(2026, 5, 17, 9, 0, 0) do
      @version.mark_printed!
    end

    assert_equal original_printed_at, @version.reload.printed_at
  end
end
