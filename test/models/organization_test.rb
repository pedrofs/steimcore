require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "requires a name" do
    organization = Organization.new

    assert_not organization.valid?
    assert_includes organization.errors[:name], "can't be blank"
  end

  test "has many users" do
    organization = organizations(:steimfit)

    assert_includes organization.users, users(:one)
    assert_includes organization.users, users(:two)
  end

  test "defaults equipment_list_md to an empty string" do
    organization = Organization.create!(name: "FreshGym")

    assert_equal "", organization.equipment_list_md
  end
end
