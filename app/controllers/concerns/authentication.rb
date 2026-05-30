module Authentication
  extend ActiveSupport::Concern

  included do
    class_attribute :authenticatable_class, instance_writer: false, default: User

    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end

    def authenticates_as(model_class)
      self.authenticatable_class = model_class
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      return unless cookies.signed[:session_id]

      session = Session.find_by(id: cookies.signed[:session_id])
      session if session&.authenticatable_type == authenticatable_class.name
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to unauthenticated_redirect_path
    end

    def unauthenticated_redirect_path
      new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(authenticatable)
      authenticatable.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
