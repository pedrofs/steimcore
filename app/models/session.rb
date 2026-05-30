class Session < ApplicationRecord
  belongs_to :authenticatable, polymorphic: true
  belongs_to :selected_student, class_name: "Student", optional: true
end
