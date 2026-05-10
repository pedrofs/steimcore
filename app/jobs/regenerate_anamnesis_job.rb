class RegenerateAnamnesisJob < ApplicationJob
  queue_as :default

  def perform(voice_recording)
    voice_recording.regenerate_anamnesis!
  end
end
