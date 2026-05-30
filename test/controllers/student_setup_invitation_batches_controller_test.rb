require "test_helper"

class StudentSetupInvitationBatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
  end

  test "create redirects to login when unauthenticated" do
    post student_setup_invitation_batch_path
    assert_redirected_to new_session_path
  end

  test "create invites every eligible pending identity and excludes confirmed, no-email, archived, and other-org students" do
    sign_in_as(@user)

    eligible_one = @organization.students.create!(name: "Eligible One", email: "e1@example.com")
    eligible_two = @organization.students.create!(name: "Eligible Two", email: "e2@example.com")
    confirmed = @organization.students.create!(name: "Confirmed", email: "c@example.com")
    confirmed.student_identity.update!(password: "password")
    no_email = @organization.students.create!(name: "No Email")
    archived = @organization.students.create!(name: "Archived", email: "a@example.com")
    archived.update!(archived_at: Time.current)

    other_org = Organization.create!(name: "Other org")
    other_org.students.create!(name: "Stranger", email: "stranger@example.com")

    assert_enqueued_emails 2 do
      post student_setup_invitation_batch_path
    end

    assert_not_nil eligible_one.student_identity.reload.last_invited_at
    assert_not_nil eligible_two.student_identity.reload.last_invited_at
    assert_nil confirmed.student_identity.reload.last_invited_at
    assert_nil archived.student_identity.reload.last_invited_at

    assert_redirected_to students_path
    assert_match(/2/, flash[:notice])
  end

  test "create skips identities under cooldown without enqueuing and reports them as waiting" do
    sign_in_as(@user)

    ready = @organization.students.create!(name: "Ready", email: "ready@example.com")
    waiting = @organization.students.create!(name: "Waiting", email: "waiting@example.com")
    invited_at = 1.hour.ago
    waiting.student_identity.update!(last_invited_at: invited_at)

    assert_enqueued_emails 1 do
      post student_setup_invitation_batch_path
    end

    assert_not_nil ready.student_identity.reload.last_invited_at
    assert_in_delta invited_at.to_f, waiting.student_identity.reload.last_invited_at.to_f, 1.0

    assert_redirected_to students_path
    notice = flash[:notice]
    assert_match(/1/, notice)
  end
end
