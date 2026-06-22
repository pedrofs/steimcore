# Server-side product analytics for the student app. We never load ahoy.js — every
# event is tracked from a student controller via the Student::Trackable concern, so
# visits and events land in Postgres (ahoy_visits / ahoy_events) with no external
# service and no client runtime.
class Ahoy::Store < Ahoy::DatabaseStore
end

# Create a visit row only when an event is actually tracked (i.e. inside a student
# controller). Trainer pages, the Jobs dashboard, and health checks never call
# `ahoy.track`, so they get no DB visit — keeping the dataset student-only.
Ahoy.server_side_visits = :when_needed

# The visitor behind a visit is the StudentIdentity — the stable, cross-org
# principal behind the student app. nil on the chrome-less auth/onboarding requests
# (no session yet), which is expected; those events still carry student_identity_id
# in their properties. Current.student_identity is nil-safe for non-student
# principals, so trainer requests never attach a user.
Ahoy.user_method = ->(_controller) { Current.student_identity }

# Keep usage signal without precise geolocation: mask the last IP octet and never
# geocode (also avoids the extra runtime dependency). geocode is already false by
# default; pinned so an upstream default flip can't silently turn it on.
Ahoy.mask_ips = true
Ahoy.geocode = false
