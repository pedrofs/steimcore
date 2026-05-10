class GeneratePeriodizationJob < ApplicationJob
  queue_as :default

  def perform(periodization_version)
    periodization_version.generate!
  end
end
