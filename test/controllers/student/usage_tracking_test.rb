require "test_helper"

# End-to-end coverage for the server-side student-app instrumentation: real requests
# through the full stack should land ahoy events carrying the identity triad, attach
# the visit to the StudentIdentity, and never fire for unauthenticated visitors.
class Student::UsageTrackingTest < ActionDispatch::IntegrationTest
  # A current desktop Chrome UA: recognised by device_detector (so ahoy doesn't
  # treat it as a bot the way it does the nil-device "Rails Testing" default) and
  # modern enough to clear `allow_browser versions: :modern` (Chrome >= 120).
  BROWSER_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36".freeze

  setup do
    @identity = student_identities(:confirmed)
    @student = @identity.students.create!(
      name: "Connie Confirmed",
      organization: organizations(:steimfit),
      email: @identity.email_address
    )
  end

  test "home view records student.home_viewed with the identity triad and entry_state" do
    sign_in_with_selected_profile(@identity, @student)

    assert_difference -> { Ahoy::Event.where(name: "student.home_viewed").count }, 1 do
      get student_home_path, headers: { "HTTP_USER_AGENT" => BROWSER_UA }
    end

    event = Ahoy::Event.where(name: "student.home_viewed").last
    assert_equal @student.organization_id, event.properties["organization_id"]
    assert_equal @student.id, event.properties["student_id"]
    assert_equal @identity.id, event.properties["student_identity_id"]
    assert_includes %w[resume can_start rest_day no_plan], event.properties["entry_state"]
  end

  test "the visit is associated with the StudentIdentity" do
    sign_in_with_selected_profile(@identity, @student)

    get student_home_path, headers: { "HTTP_USER_AGENT" => BROWSER_UA }

    assert_equal @identity, Ahoy::Visit.last.user
  end

  test "unauthenticated visitors track no events" do
    assert_no_difference -> { Ahoy::Event.count } do
      get student_home_path, headers: { "HTTP_USER_AGENT" => BROWSER_UA }
    end
  end

  private
    def sign_in_with_selected_profile(identity, student)
      sign_in_as(identity)
      identity.sessions.sole.update!(selected_student: student)
    end
end
