class MedalEvaluationJob < ApplicationJob
  queue_as :default

  def perform(student)
    student.evaluate_medals!
  end
end
