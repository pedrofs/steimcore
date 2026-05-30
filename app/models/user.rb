class User < ApplicationRecord
  has_secure_password
  belongs_to :organization
  has_many :sessions, as: :authenticatable, dependent: :destroy
  has_many :training_sessions, foreign_key: :trainer_id do
    def start_for!(student)
      TrainingSession.start!(trainer: proxy_association.owner, student: student)
    end

    def log_past_for!(student, on_date:, workout:)
      TrainingSession.log_past!(
        trainer: proxy_association.owner,
        student: student,
        on_date: on_date,
        workout: workout
      )
    end
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
