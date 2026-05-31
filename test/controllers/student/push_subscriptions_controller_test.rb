require "test_helper"

class Student::PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup { @identity = student_identities(:confirmed) }

  test "create requires a student session" do
    post student_push_subscription_path, params: subscription_params, as: :json
    assert_redirected_to new_student_session_path
  end

  test "create registers the endpoint for the signed-in identity" do
    sign_in_as(@identity)

    assert_difference -> { @identity.push_subscriptions.count }, 1 do
      post student_push_subscription_path, params: subscription_params, as: :json
    end

    assert_response :no_content
    assert_equal "StudentIdentity", @identity.push_subscriptions.sole.authenticatable_type
  end

  private
    def subscription_params
      {
        push_subscription: {
          endpoint: "https://push.example.com/student",
          p256dh_key: "p256-key",
          auth_key: "auth-key"
        }
      }
    end
end
