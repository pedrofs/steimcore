# Render the engine's controllers through our own base controller so the User
# session authentication applies. User === trainer (students authenticate as a
# separate StudentIdentity), so this restricts the dashboard to trainers and
# adds the login redirect for unauthenticated requests.
MissionControl::Jobs.base_controller_class = "JobsDashboardController"

# Keep the gem's HTTP Basic auth on top of the trainer session gate. Credentials
# live in Rails encrypted credentials under `mission_control:` (configured per
# environment); the engine reads them in its own initializer. Without them the
# gem returns 401, so test env sets them explicitly (see the integration test).
MissionControl::Jobs.http_basic_auth_enabled = true
