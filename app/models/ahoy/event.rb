module Ahoy
  class Event < ApplicationRecord
    include Ahoy::QueryMethods

    self.table_name = "ahoy_events"

    belongs_to :visit, class_name: "Ahoy::Visit"

    # Every student event carries the identity triad (organization_id, student_id,
    # student_identity_id) in +properties+. Scope to one trainer's organization via
    # a jsonb containment match (QueryMethods#where_props → properties @> …, backed
    # by the gin index).
    scope :for_organization, ->(organization) { where_props(organization_id: organization.id) }
  end
end
