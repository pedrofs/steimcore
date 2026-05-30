require "test_helper"

class Student::SetupAcceptancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = student_identities(:pending)
    @token = @identity.generate_token_for(:setup)
  end

  test "edit is reachable without authentication" do
    get edit_student_setup_acceptance_path(@token)

    assert_response :success
    assert_equal "student/setup_acceptances/edit", inertia.component
    assert_equal @identity.email_address, inertia.props[:email_address]
  end

  test "edit redirects to student sign-in when the token signature is invalid" do
    get edit_student_setup_acceptance_path("totally-bogus-token")

    assert_redirected_to new_student_session_path
    assert_equal "Este convite não é mais válido.", flash[:alert]
  end

  test "edit redirects to student sign-in when the token has expired" do
    travel 31.days do
      get edit_student_setup_acceptance_path(@token)
    end

    assert_redirected_to new_student_session_path
    assert_equal "Este convite não é mais válido.", flash[:alert]
  end

  test "update with a valid token and matching password sets the digest, signs in, auto-selects the single profile, lands on the placeholder home" do
    assert_nil @identity.password_digest
    @identity.students.create!(name: "Only Profile", organization: organizations(:steimfit), email: @identity.email_address)

    put student_setup_acceptance_path(@token), params: {
      password: "newpassword",
      password_confirmation: "newpassword"
    }

    @identity.reload
    assert_not_nil @identity.password_digest
    assert @identity.authenticate("newpassword")
    assert @identity.confirmed?
    assert cookies[:session_id]
    assert_redirected_to student_home_path
    assert_equal @identity.students.sole.id, @identity.sessions.sole.selected_student_id
  end

  test "update routes a multi-profile identity to the chooser after sign-in" do
    other_org = Organization.create!(name: "Other Gym", equipment_list_md: "")
    @identity.students.create!(name: "Profile One", organization: organizations(:steimfit), email: @identity.email_address)
    other_org.students.create!(name: "Profile Two", email: @identity.email_address)

    put student_setup_acceptance_path(@token), params: {
      password: "newpassword",
      password_confirmation: "newpassword"
    }

    assert cookies[:session_id]
    assert_redirected_to new_student_profile_selection_path
  end

  test "update routes a zero-profile identity to the no-profile page after sign-in" do
    put student_setup_acceptance_path(@token), params: {
      password: "newpassword",
      password_confirmation: "newpassword"
    }

    assert cookies[:session_id]
    assert_redirected_to student_no_profile_path
  end

  test "update with a token for an already-confirmed identity redirects with alert" do
    @identity.complete_setup!(password: "newpassword", password_confirmation: "newpassword")

    put student_setup_acceptance_path(@token), params: {
      password: "another-pass",
      password_confirmation: "another-pass"
    }

    assert_redirected_to new_student_session_path
    assert_equal "Este convite não é mais válido.", flash[:alert]
  end

  test "update with mismatched password re-renders edit with inertia errors" do
    put student_setup_acceptance_path(@token), params: {
      password: "secret-one",
      password_confirmation: "secret-two"
    }

    assert_redirected_to edit_student_setup_acceptance_path(@token)
    errors = session[:inertia_errors] || {}
    assert errors.values.flatten.any? { |m| m.match?(/doesn't match/i) },
           "expected confirmation-mismatch error, got: #{errors.inspect}"
    assert_nil @identity.reload.password_digest
  end

  test "end-to-end: a trainer invite delivers mail whose token is resolvable by edit and consumable by update" do
    organization = organizations(:steimfit)
    @identity.students.create!(name: "Eve Student", organization: organization, email: @identity.email_address)

    perform_enqueued_jobs do
      @identity.invite!(from_organization: organization)
    end

    mail = ActionMailer::Base.deliveries.last
    token = mail.text_part.body.to_s.match(%r{/student/setup_acceptances/([^/\s"<]+)})[1]

    get edit_student_setup_acceptance_path(token)
    assert_response :success
    assert_equal @identity.email_address, inertia.props[:email_address]

    put student_setup_acceptance_path(token), params: {
      password: "fromthemail",
      password_confirmation: "fromthemail"
    }

    assert_redirected_to student_home_path
    assert @identity.reload.confirmed?
  end
end
