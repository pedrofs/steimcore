class Periodization < ApplicationRecord
  include Archivable

  belongs_to :student
  belongs_to :current_version, class_name: "PeriodizationVersion", optional: true
  has_many :versions, class_name: "PeriodizationVersion", dependent: :destroy

  def set_current_version!(version)
    raise ArgumentError, "version must belong to this periodization" unless version.periodization_id == id
    update!(current_version: version)
  end
end
