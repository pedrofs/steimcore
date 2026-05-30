require "test_helper"

class Students::SetupInvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
  end

  test "create redirects to login when unauthenticated" do
    student = @organization.students.create!(name: "Dana", email: "dana@example.com")
    post student_setup_invitation_path(student)
    assert_redirected_to new_session_path
  end

  test "create invites a pending identity, enqueues the mailer, stamps last_invited_at, and redirects with notice" do
    sign_in_as(@user)
    student = @organization.students.create!(name: "Dana", email: "dana@example.com")

    assert_enqueued_emails 1 do
      post student_setup_invitation_path(student)
    end

    assert_not_nil student.student_identity.reload.last_invited_at
    assert_redirected_to student_path(student)
    assert_match(/Convite enviado para dana@example\.com\./, flash[:notice])
  end

  test "create on a student with no email redirects with alert and sends nothing" do
    sign_in_as(@user)
    student = @organization.students.create!(name: "Noemail")

    assert_enqueued_emails 0 do
      post student_setup_invitation_path(student)
    end

    assert_redirected_to student_path(student)
    assert flash[:alert].present?
  end

  test "create on an already-confirmed identity redirects with alert and sends nothing" do
    sign_in_as(@user)
    student = @organization.students.create!(name: "Confirmed Connie", email: "connie@example.com")
    student.student_identity.update!(password: "password")

    assert_enqueued_emails 0 do
      post student_setup_invitation_path(student)
    end

    assert_redirected_to student_path(student)
    assert flash[:alert].present?
  end

  test "create on an identity under cooldown redirects with alert and does not re-stamp last_invited_at" do
    sign_in_as(@user)
    student = @organization.students.create!(name: "Cooldown Cora", email: "cora@example.com")
    invited_at = 1.hour.ago
    student.student_identity.update!(last_invited_at: invited_at)

    assert_enqueued_emails 0 do
      post student_setup_invitation_path(student)
    end

    assert_in_delta invited_at.to_f, student.student_identity.reload.last_invited_at.to_f, 1.0
    assert_redirected_to student_path(student)
    assert flash[:alert].present?
  end

  test "create on another org's student 404s" do
    sign_in_as(@user)
    other_org = Organization.create!(name: "Other org")
    foreign = other_org.students.create!(name: "Foreign", email: "foreign@example.com")

    assert_enqueued_emails 0 do
      post student_setup_invitation_path(foreign)
    end

    assert_response :not_found
  end
end
