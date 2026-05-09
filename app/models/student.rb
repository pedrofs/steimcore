class Student < ApplicationRecord
  include Archivable

  belongs_to :organization
  has_many :voice_recordings, dependent: :destroy

  validates :name, presence: true
end
