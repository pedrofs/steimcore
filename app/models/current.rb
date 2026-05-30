class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :organization, to: :user, allow_nil: true

  def user
    principal = session&.authenticatable
    principal if principal.is_a?(User)
  end

  def student_identity
    principal = session&.authenticatable
    principal if principal.is_a?(StudentIdentity)
  end

  # The Selected profile for the current session — the Student the signed-in
  # identity is viewing. Returns nil when there is no identity, no selection, or
  # the selection is no longer reachable from the identity's students (e.g. the
  # trainer destroyed that Student mid-session). See PRD #108, Profile chooser.
  def student
    return unless session&.selected_student_id

    student_identity&.students&.find_by(id: session.selected_student_id)
  end
end
