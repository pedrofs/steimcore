# Base controller for the Mission Control Jobs engine. It inherits the User
# session authentication from ApplicationController, but because the engine is
# namespace-isolated, unqualified route helpers resolve against the engine's
# routes — so the login redirect has to go through `main_app`.
class JobsDashboardController < ApplicationController
  private
    def unauthenticated_redirect_path
      main_app.new_session_path
    end
end
