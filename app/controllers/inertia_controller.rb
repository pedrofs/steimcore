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

  inertia_share inbox_count: -> {
    next 0 unless Current.user

    Inbox.new(trainer: Current.user).count
  }

  inertia_share active_session_count: -> {
    next 0 unless Current.user

    Current.user.training_sessions.where(finished_at: nil).count
  }

  private
    def current_organization
      Current.organization
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
