module Student::Trackable
  extend ActiveSupport::Concern

  private
    # Records a server-side ahoy event for the current student request. The name is
    # namespaced (student.<name>) and the event always carries the identity triad
    # (organization_id, student_id, student_identity_id) where a profile/identity is
    # available; callers pass only the event-specific properties. The first track in
    # a visit window lazily creates the visit (Ahoy.server_side_visits = :when_needed)
    # and authenticate stamps the StudentIdentity onto it.
    #
    # Best-effort: ahoy already rescues internally, but we guard anyway so a tracking
    # hiccup can never break a student mid-workout.
    def track(name, **properties)
      ahoy.track "student.#{name}", student_context.merge(properties)
      ahoy.authenticate(Current.student_identity) if Current.student_identity
    rescue => e
      Rails.logger.warn("[student-analytics] #{name} tracking failed: #{e.class}: #{e.message}")
    end

    def student_context
      {
        organization_id: Current.student&.organization_id,
        student_id: Current.student&.id,
        student_identity_id: Current.student_identity&.id
      }.compact
    end
end
