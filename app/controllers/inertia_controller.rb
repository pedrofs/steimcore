# frozen_string_literal: true

class InertiaController < ApplicationController
  include PageMetadata

  inertia_share current_user: -> {
    next nil unless Current.user

    {
      id: Current.user.id,
      email: Current.user.email_address
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
end
