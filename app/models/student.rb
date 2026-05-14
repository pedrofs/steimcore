class Student < ApplicationRecord
  include Archivable

  belongs_to :organization
  belongs_to :active_periodization, class_name: "Periodization", optional: true
  has_many :voice_recordings, dependent: :destroy
  has_many :periodizations, dependent: :destroy
  has_many :training_sessions, dependent: :destroy
  has_one :agent_chat, class_name: "Agent::Chat", as: :chattable, dependent: :destroy

  validates :name, presence: true

  def age(today: Date.current)
    return nil if birthday.nil?
    age = today.year - birthday.year
    age -= 1 if today < birthday + age.years
    age
  end

  # Begins a new periodization for this student. If an active one exists, it
  # gets archived in the same transaction; the new periodization is created
  # with a first PeriodizationVersion in :generating, the student is repointed
  # to the new periodization, and the new version is returned for the caller
  # to enqueue generation against.
  #
  # `voice_recording:` is optional — the voice pipeline passes it so the
  # resulting version carries the originating recording reference; the agent
  # chat flow leaves it nil (the originator there is an Agent::ToolCall, set
  # downstream by the tool).
  def start_periodization!(trainer:, voice_recording: nil)
    transaction do
      active_periodization&.archive!

      new_periodization = periodizations.create!
      new_version = new_periodization.versions.create!(
        trainer: trainer,
        voice_recording: voice_recording,
        parent_version: nil
      )
      new_version.transition_to!(:generating)

      update!(active_periodization: new_periodization)

      new_version
    end
  end
end
