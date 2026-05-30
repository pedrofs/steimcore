class Session < ApplicationRecord
  belongs_to :authenticatable, polymorphic: true
end
