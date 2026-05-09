ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "inertia_rails/testing"
require_relative "test_helpers/session_test_helper"

InertiaRails::Testing.install!

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include InertiaRails::Testing::Helpers
end
