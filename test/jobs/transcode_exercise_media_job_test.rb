require "test_helper"

class TranscodeExerciseMediaJobTest < ActiveJob::TestCase
  test "perform optimizes the exercise's pending videos" do
    exercise = Exercise.create!(name: "Agachamento")
    exercise.media.attach(io: StringIO.new("raw"), filename: "clip.mov", content_type: "video/quicktime")

    optimized = []
    Exercise::MediaTranscoder.stub(:call, ->(attachment) { optimized << attachment.id }) do
      TranscodeExerciseMediaJob.perform_now(exercise)
    end

    assert_equal [ exercise.media.first.id ], optimized
  end
end
