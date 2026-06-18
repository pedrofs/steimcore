# Mission Control Jobs extends the host app's ApplicationController, so access is
# already gated by the existing User session authentication (see
# app/controllers/concerns/authentication.rb). Disable the gem's built-in HTTP
# Basic auth so we rely on that single mechanism rather than a separate password.
MissionControl::Jobs.http_basic_auth_enabled = false

# Render the engine's controllers through our own base controller so the User
# session authentication (and its login redirect) applies to the dashboard.
MissionControl::Jobs.base_controller_class = "JobsDashboardController"
