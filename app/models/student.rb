class Student < ApplicationRecord
  include Archivable

  belongs_to :organization

  validates :name, presence: true
end
