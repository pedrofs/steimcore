require "test_helper"

class Students::Periodizations::Versions::PrintConfirmationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
  end

  test "create marks the version printed and redirects to the printable with a success flash" do
    version = promote_completed_plan!

    sign_in_as(@user)
    freeze_time do
      post student_periodization_version_print_confirmation_path(@student, version.periodization, version)

      assert_redirected_to student_periodization_printable_path(@student)
      assert_match(/impressão registrada/i, flash[:notice])
      assert_equal Time.current, version.reload.printed_at
    end
  end

  test "create is a no-op on a version already printed and keeps the original timestamp" do
    version = promote_completed_plan!
    original_printed_at = Time.zone.local(2026, 4, 1, 12, 0, 0)
    version.update!(printed_at: original_printed_at)

    sign_in_as(@user)
    travel_to Time.zone.local(2026, 5, 17, 9, 0, 0) do
      post student_periodization_version_print_confirmation_path(@student, version.periodization, version)
    end

    assert_redirected_to student_periodization_printable_path(@student)
    assert_equal original_printed_at, version.reload.printed_at
  end

  test "create succeeds even when the version status is not :completed" do
    version = @student.start_periodization!(trainer: @user)
    assert_not_equal "completed", version.status

    sign_in_as(@user)
    freeze_time do
      post student_periodization_version_print_confirmation_path(@student, version.periodization, version)

      assert_redirected_to student_periodization_printable_path(@student)
      assert_equal Time.current, version.reload.printed_at
    end
  end

  test "create is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    foreign_trainer = other_org.users.create!(
      email_address: "outro@example.com",
      password: "password123"
    )
    foreign_version = promote_completed_plan!(student: foreign_student, trainer: foreign_trainer)

    sign_in_as(@user)

    post student_periodization_version_print_confirmation_path(
      foreign_student, foreign_version.periodization, foreign_version
    )

    assert_response :not_found
    assert_nil foreign_version.reload.printed_at
  end

  private
    def promote_completed_plan!(student: @student, trainer: @user)
      version = student.start_periodization!(trainer: trainer)
      version.fork_with!(
        scope: :create,
        patch: { body_md: "## Plano", workouts: [
          { name: "A", blocks: [], position: 1 }
        ] },
        trainer: trainer
      )
      version.transition_to!(:completed)
      version.periodization.set_current_version!(version)
      version
    end
end
