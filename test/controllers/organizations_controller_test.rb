require "test_helper"

class OrganizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @organization = @user.organization
  end

  test "show redirects unauthenticated visitors to sign in" do
    get organization_path

    assert_redirected_to new_session_path
  end

  test "show renders the current organization name and equipment list" do
    @organization.update!(equipment_list_md: "- 2 leg presses\n- dumbbells up to 30kg")
    sign_in_as(@user)

    get organization_path

    assert_response :success
    assert_equal "organizations/show", inertia.component
    assert_equal @organization.id, inertia.props[:organization][:id]
    assert_equal @organization.name, inertia.props[:organization][:name]
    assert_equal "- 2 leg presses\n- dumbbells up to 30kg", inertia.props[:organization][:equipment_list_md]
  end

  test "edit redirects unauthenticated visitors to sign in" do
    get edit_organization_path

    assert_redirected_to new_session_path
  end

  test "edit renders the current organization for editing" do
    @organization.update!(equipment_list_md: "barras olímpicas")
    sign_in_as(@user)

    get edit_organization_path

    assert_response :success
    assert_equal "organizations/edit", inertia.component
    assert_equal @organization.id, inertia.props[:organization][:id]
    assert_equal "barras olímpicas", inertia.props[:organization][:equipment_list_md]
  end

  test "update persists the equipment list to the signed-in trainer's organization" do
    sign_in_as(@user)

    patch organization_path, params: { organization: { equipment_list_md: "leg press novo" } }

    assert_redirected_to organization_path
    assert_equal "leg press novo", @organization.reload.equipment_list_md
  end

  test "update is idempotent" do
    sign_in_as(@user)

    patch organization_path, params: { organization: { equipment_list_md: "barras" } }
    patch organization_path, params: { organization: { equipment_list_md: "barras" } }

    assert_redirected_to organization_path
    assert_equal "barras", @organization.reload.equipment_list_md
  end

  test "edits by one trainer are visible to other trainers in the same organization" do
    sign_in_as(@user)
    patch organization_path, params: { organization: { equipment_list_md: "halteres 1-30kg" } }

    sign_out
    sign_in_as(@other_user)

    get organization_path

    assert_equal @organization.id, @other_user.organization_id, "fixture precondition: users share the same organization"
    assert_equal "halteres 1-30kg", inertia.props[:organization][:equipment_list_md]
  end

  test "update ignores any user-supplied id and only touches current_organization" do
    other_org = Organization.create!(name: "Other Gym", equipment_list_md: "intocada")
    sign_in_as(@user)

    patch organization_path, params: { id: other_org.id, organization: { equipment_list_md: "novo" } }

    assert_equal "novo", @organization.reload.equipment_list_md
    assert_equal "intocada", other_org.reload.equipment_list_md
  end
end
