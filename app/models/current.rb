class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :organization, to: :user, allow_nil: true

  def user
    principal = session&.authenticatable
    principal if principal.is_a?(User)
  end
end
