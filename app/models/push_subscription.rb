class PushSubscription < ApplicationRecord
  include Deliverable

  belongs_to :authenticatable, polymorphic: true

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, :auth_key, presence: true
end
