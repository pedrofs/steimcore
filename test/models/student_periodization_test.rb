require "test_helper"

# Focuses on the periodization-flow methods on Student. The base Student
# behaviour lives in test/models/student_test.rb.
class StudentPeriodizationTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:steimfit)
    @student = students(:alice)
    @trainer = users(:one)
    @recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @trainer,
      kind: "periodization_create"
    )
  end

  test "start_periodization! creates a new periodization with a generating version and repoints the student" do
    assert_nil @student.active_periodization_id

    version = @student.start_periodization!(trainer: @trainer, voice_recording: @recording)

    @student.reload
    assert_equal version.periodization_id, @student.active_periodization_id
    assert_equal "generating", version.status
    assert_equal @trainer, version.trainer
    assert_equal @recording, version.voice_recording
    assert_nil version.parent_version_id
  end

  test "start_periodization! archives the prior active periodization in the same transaction" do
    first = @student.start_periodization!(trainer: @trainer, voice_recording: @recording)
    first_periodization = first.periodization
    assert_not first_periodization.archived?

    second_recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @trainer,
      kind: "periodization_create"
    )

    second = @student.start_periodization!(trainer: @trainer, voice_recording: second_recording)

    assert first_periodization.reload.archived?
    assert_not second.periodization.reload.archived?
    assert_equal second.periodization_id, @student.reload.active_periodization_id
    assert_not_equal first.periodization_id, second.periodization_id
  end
end
