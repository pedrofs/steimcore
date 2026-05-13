class Organization < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception
  has_many :students, dependent: :restrict_with_exception
  has_many :invitations, dependent: :destroy

  validates :name, presence: true
end
