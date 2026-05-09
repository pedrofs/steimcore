require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "requires an organization" do
    user = User.new(email_address: "neworg@example.com", password: "secret")

    assert_not user.valid?
    assert_includes user.errors[:organization], "must exist"
  end

  test "is valid when scoped to an organization" do
    user = User.new(
      email_address: "valid@example.com",
      password: "secret",
      organization: organizations(:steimfit)
    )

    assert user.valid?, user.errors.full_messages.to_sentence
  end
end
