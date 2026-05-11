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

  private
    def current_organization
      Current.organization
    end
end
