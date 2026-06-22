module Ahoy
  class Visit < ApplicationRecord
    self.table_name = "ahoy_visits"

    has_many :events, class_name: "Ahoy::Event", dependent: :destroy

    # Student-only tracking, so the visitor is always a StudentIdentity (uuid).
    # Single-target — not the polymorphic User|StudentIdentity principal pattern.
    belongs_to :user, class_name: "StudentIdentity", optional: true
  end
end
