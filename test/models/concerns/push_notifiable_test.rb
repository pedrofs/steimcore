require "test_helper"

class PushNotifiableTest < ActiveSupport::TestCase
  test "notify enqueues one delivery job per subscription" do
    user = users(:one)
    user.push_subscriptions.create!(endpoint: "https://push.example.com/1", p256dh_key: "p", auth_key: "a")
    user.push_subscriptions.create!(endpoint: "https://push.example.com/2", p256dh_key: "p", auth_key: "a")

    assert_enqueued_jobs 2, only: WebPushDeliveryJob do
      user.notify(title: "Olá", body: "corpo", path: "/x")
    end
  end

  test "notify is a no-op without subscriptions" do
    assert_no_enqueued_jobs do
      users(:two).notify(title: "Olá")
    end
  end
end
