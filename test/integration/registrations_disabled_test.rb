require "test_helper"

class RegistrationsDisabledTest < ActionDispatch::IntegrationTest
  test "no registration route helpers are defined" do
    assert_not Rails.application.routes.url_helpers.respond_to?(:new_registration_path)
    assert_not Rails.application.routes.url_helpers.respond_to?(:registration_path)
  end

  test "GET /registration/new does not resolve to a controller" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/registration/new", method: :get)
    end
  end

  test "POST /registration does not resolve to a controller" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/registration", method: :post)
    end
  end
end
