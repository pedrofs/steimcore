require "test_helper"

class EnrichExerciseJobTest < ActiveJob::TestCase
  test "perform runs the record's taxonomy enrichment" do
    exercise = Exercise.create!(name: "Stiff")

    Exercise::Enricher.stub(:classify, { family: "Levantamento terra", muscle_group: "Posterior de coxa" }) do
      EnrichExerciseJob.perform_now(exercise)
    end

    exercise.reload
    assert_equal "Levantamento terra", exercise.exercise_family.name
    assert_equal "Posterior de coxa", exercise.muscle_group.name
  end
end
