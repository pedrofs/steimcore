# frozen_string_literal: true

module PageMetadata
  extend ActiveSupport::Concern

  class_methods do
    def with_title(title)
      before_action { set_title(title) }
    end

    def with_breadcrumb(label:, path:)
      before_action { add_breadcrumb(label: label, path: path) }
    end
  end

  private

  def set_title(title)
    @title = title
  end

  def add_breadcrumb(label:, path:)
    @breadcrumbs ||= []
    resolved_path = path.respond_to?(:call) ? instance_exec(&path) : path
    @breadcrumbs << { label: label, path: resolved_path }
  end
end
