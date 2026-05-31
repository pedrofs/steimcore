require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "create requires authentication" do
    post push_subscription_path, params: subscription_params, as: :json
    assert_redirected_to new_session_path
  end

  test "create registers the endpoint for the signed-in trainer" do
    sign_in_as(@user)

    assert_difference -> { @user.push_subscriptions.count }, 1 do
      post push_subscription_path, params: subscription_params, as: :json
    end

    assert_response :no_content
    subscription = @user.push_subscriptions.sole
    assert_equal "https://push.example.com/endpoint", subscription.endpoint
    assert_equal "p256-key", subscription.p256dh_key
    assert_equal "auth-key", subscription.auth_key
  end

  test "create is idempotent on the endpoint" do
    sign_in_as(@user)

    assert_difference -> { PushSubscription.count }, 1 do
      2.times { post push_subscription_path, params: subscription_params, as: :json }
    end
  end

  test "create reclaims an endpoint owned by another principal" do
    other = users(:two)
    other.push_subscriptions.create!(endpoint: "https://push.example.com/endpoint", p256dh_key: "old", auth_key: "old")

    sign_in_as(@user)
    post push_subscription_path, params: subscription_params, as: :json

    assert_response :no_content
    subscription = PushSubscription.find_by(endpoint: "https://push.example.com/endpoint")
    assert_equal @user, subscription.authenticatable
    assert_equal "p256-key", subscription.p256dh_key
  end

  test "destroy removes the browser's endpoint" do
    sign_in_as(@user)
    @user.push_subscriptions.create!(endpoint: "https://push.example.com/endpoint", p256dh_key: "p", auth_key: "a")

    assert_difference -> { @user.push_subscriptions.count }, -1 do
      delete push_subscription_path(endpoint: "https://push.example.com/endpoint")
    end

    assert_response :no_content
  end

  private
    def subscription_params
      {
        push_subscription: {
          endpoint: "https://push.example.com/endpoint",
          p256dh_key: "p256-key",
          auth_key: "auth-key"
        }
      }
    end
end
