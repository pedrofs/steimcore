require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "redirects unauthenticated visitors to sign in" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "renders the home page for a signed-in trainer" do
    sign_in_as(@user)

    get root_path

    assert_response :success
  end

  test "shares current_organization derived from the signed-in user" do
    sign_in_as(@user)

    get root_path

    org = inertia.props[:current_organization]

    assert_equal @user.organization.id, org[:id]
    assert_equal @user.organization.name, org[:name]
  end

  test "shares a nil current_organization when nobody is signed in" do
    get new_session_path

    assert_nil inertia.props[:current_organization]
  end

  test "shares inbox_count as 0 when the trainer has no actionable items" do
    sign_in_as(@user)

    get root_path

    assert_equal 0, inertia.props[:inbox_count]
  end

  test "shares inbox_count counting failed-not-dismissed and ready items only" do
    organization = @user.organization
    student = students(:alice)

    failed = VoiceRecording.create!(
      organization: organization, student: student, trainer: @user, kind: "anamnesis"
    )
    failed.transition_to!(:transcribing)
    failed.fail!("boom")

    ready = VoiceRecording.create!(
      organization: organization, student: student, trainer: @user, kind: "anamnesis"
    )
    ready.transition_to!(:transcribing)
    ready.update!(transcript: "x")
    ready.transition_to!(:transcribed)
    ready.transition_to!(:generating)
    ready.update!(proposed_anamnesis_md: "## P")
    ready.transition_to!(:completed)

    in_flight = VoiceRecording.create!(
      organization: organization, student: student, trainer: @user, kind: "anamnesis"
    )
    in_flight.transition_to!(:transcribing)

    sign_in_as(@user)

    get root_path

    assert_equal 2, inertia.props[:inbox_count]
  end

  test "shares inbox_count as 0 when nobody is signed in" do
    get new_session_path

    assert_equal 0, inertia.props[:inbox_count]
  end
end
