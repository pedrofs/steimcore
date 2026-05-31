# frozen_string_literal: true

class InertiaController < ApplicationController
  include PageMetadata

  helper_method :current_organization

  inertia_share current_user: -> {
    next nil unless Current.user

    {
      id: Current.user.id,
      email: Current.user.email_address
    }
  }

  inertia_share current_organization: -> {
    next nil unless current_organization

    {
      id: current_organization.id,
      name: current_organization.name
    }
  }

  inertia_share flash: -> {
    {
      notice: flash[:notice],
      alert: flash[:alert]
    }.compact
  }

  inertia_share title: -> { @title }
  inertia_share breadcrumbs: -> { @breadcrumbs || [] }

  # Everything the client needs to register a web-push subscription: the VAPID
  # public key handed to `pushManager.subscribe`, and the RESTful endpoint to
  # POST/DELETE the subscription to. `subscription_path` is overridden per auth
  # boundary (see Student::ApplicationController) so the subscription is owned by
  # the right principal.
  inertia_share web_push: -> {
    {
      vapid_public_key: Rails.application.config.x.web_push.vapid_public_key,
      subscription_path: web_push_subscription_path
    }
  }

  inertia_share active_session_count: -> {
    next 0 unless Current.user

    Current.user.training_sessions.where(finished_at: nil).count
  }

  # Front-end feature flags. Student invites are still being rolled out, so the
  # trainer-facing invite affordances are gated to development for now.
  inertia_share features: -> {
    {
      student_invites: Rails.env.development?
    }
  }

  private
    def current_organization
      Current.organization
    end

    # The RESTful push-subscription endpoint for this auth boundary. Overridden
    # in Student::ApplicationController to point at the student-namespaced route.
    def web_push_subscription_path
      push_subscription_path
    end

    # Same-origin allowlist for `return_to` query params. The trainer-facing
    # drawer (and similar surfaces) want a write action to bounce back to the
    # page that initiated it instead of the controller's default destination.
    # Accept the value only when it's a relative path so callers cannot smuggle
    # in cross-origin URLs.
    def safe_return_to
      value = params[:return_to].to_s
      return nil if value.empty?
      return nil unless value.start_with?("/") && !value.start_with?("//")

      value
    end
end
