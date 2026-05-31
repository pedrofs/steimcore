require "test_helper"

class PushSubscriptionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @subscription = @user.push_subscriptions.create!(
      endpoint: "https://push.example.com/abc",
      p256dh_key: "p256",
      auth_key: "auth"
    )

    @web_push = Rails.application.config.x.web_push
    @saved = { pub: @web_push.vapid_public_key, priv: @web_push.vapid_private_key, sub: @web_push.vapid_subject }
    @web_push.vapid_public_key = "test_public_key"
    @web_push.vapid_private_key = "test_private_key"
    @web_push.vapid_subject = "mailto:test@example.com"
  end

  teardown do
    @web_push.vapid_public_key = @saved[:pub]
    @web_push.vapid_private_key = @saved[:priv]
    @web_push.vapid_subject = @saved[:sub]
  end

  test "requires endpoint, keys and a unique endpoint" do
    assert_not PushSubscription.new(authenticatable: @user).valid?

    dup = @user.push_subscriptions.build(endpoint: @subscription.endpoint, p256dh_key: "x", auth_key: "y")
    assert_not dup.valid?
    assert_includes dup.errors[:endpoint], "has already been taken"
  end

  test "belongs to either principal type" do
    identity = student_identities(:confirmed)
    sub = identity.push_subscriptions.create!(endpoint: "https://push.example.com/s", p256dh_key: "p", auth_key: "a")

    assert_equal "StudentIdentity", sub.authenticatable_type
    assert_equal identity, sub.authenticatable
  end

  test "notify! signs the push with the configured VAPID identity and payload" do
    captured = nil
    stub_module_method(WebPush, :payload_send, ->(**kwargs) { captured = kwargs }) do
      @subscription.notify!(title: "Treino", body: "Bora treinar", path: "/students")
    end

    assert_equal @subscription.endpoint, captured[:endpoint]
    assert_equal "p256", captured[:p256dh]
    assert_equal "auth", captured[:auth]
    assert_equal "test_public_key", captured[:vapid][:public_key]
    assert_equal "mailto:test@example.com", captured[:vapid][:subject]

    message = JSON.parse(captured[:message])
    assert_equal "Treino", message["title"]
    assert_equal "Bora treinar", message["options"]["body"]
    assert_equal "/students", message["options"]["data"]["path"]
  end

  test "notify! prunes the subscription when the endpoint is gone" do
    response = Struct.new(:body).new("Gone")
    raiser = ->(**) { raise WebPush::ExpiredSubscription.new(response, "push.example.com") }

    stub_module_method(WebPush, :payload_send, raiser) do
      assert_difference -> { PushSubscription.count }, -1 do
        @subscription.notify!(title: "x")
      end
    end
  end

  test "notify! is a no-op when delivery is not configured" do
    @web_push.vapid_private_key = nil
    called = false

    stub_module_method(WebPush, :payload_send, ->(**) { called = true }) do
      @subscription.notify!(title: "x")
    end

    assert_not called
  end
end
