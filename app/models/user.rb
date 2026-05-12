class User < ApplicationRecord
  has_secure_password
  belongs_to :organization
  has_many :sessions, dependent: :destroy
  has_many :training_sessions, foreign_key: :trainer_id

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
