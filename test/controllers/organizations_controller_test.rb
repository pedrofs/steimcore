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

  test "show exposes the org's members with the documented shape and the current-user flag" do
    sign_in_as(@user)

    get organization_path

    members = inertia.props[:members]
    assert_kind_of Array, members
    member_ids = members.map { |m| m[:id] }
    assert_includes member_ids, @user.id
    assert_includes member_ids, @other_user.id

    me = members.find { |m| m[:id] == @user.id }
    other = members.find { |m| m[:id] == @other_user.id }
    assert_equal @user.email_address, me[:email]
    assert_not_nil me[:joined_at]
    assert_equal true, me[:is_current_user]
    assert_equal false, other[:is_current_user]
  end

  test "show exposes pending invitations with inviter and expired flag, excluding accepted ones" do
    sign_in_as(@user)
    pending = invitations(:pending)
    accepted = invitations(:accepted)
    pending.update!(created_at: 8.days.ago)

    get organization_path

    invites = inertia.props[:pending_invitations]
    assert_kind_of Array, invites
    invite_ids = invites.map { |i| i[:id] }
    assert_includes invite_ids, pending.id
    assert_not_includes invite_ids, accepted.id

    row = invites.find { |i| i[:id] == pending.id }
    assert_equal pending.email_address, row[:email]
    assert_equal pending.invited_by.email_address, row[:invited_by_email]
    assert_not_nil row[:invited_at]
    assert_equal true, row[:expired]
  end

  test "show pending_invitations are ordered by created_at desc" do
    sign_in_as(@user)
    older = invitations(:pending)
    older.update!(created_at: 2.days.ago)
    newer = Invitation.create!(
      organization: @organization,
      invited_by: @user,
      email_address: "newer@example.com",
      created_at: 1.minute.ago
    )

    get organization_path

    invites = inertia.props[:pending_invitations]
    ids = invites.map { |i| i[:id] }
    assert_equal [ newer.id, older.id ], ids & [ newer.id, older.id ]
  end

  test "show isolates members and pending invitations across orgs" do
    other_org = Organization.create!(name: "Other Gym")
    other_trainer = User.create!(organization: other_org, email_address: "other-trainer@example.com", password: "password")
    foreign_invitation = Invitation.create!(
      organization: other_org,
      invited_by: other_trainer,
      email_address: "foreign@example.com"
    )

    sign_in_as(@user)

    get organization_path

    member_ids = inertia.props[:members].map { |m| m[:id] }
    assert_not_includes member_ids, other_trainer.id

    invite_ids = inertia.props[:pending_invitations].map { |i| i[:id] }
    assert_not_includes invite_ids, foreign_invitation.id
  end
end
