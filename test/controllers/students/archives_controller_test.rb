require "test_helper"

class Students::ArchivesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
  end

  test "create redirects unauthenticated visitors to sign in" do
    post student_archive_path(@student), params: { archive: { reason: "Só faz crossfit" } }
    assert_redirected_to new_session_path
  end

  test "create archives the student, persists the reason, and redirects to show" do
    sign_in_as(@user)

    assert_not @student.archived?

    post student_archive_path(@student), params: { archive: { reason: "Só faz crossfit (sem musculação)" } }

    assert_redirected_to student_path(@student)
    assert_equal "Aluno arquivado.", flash[:notice]

    @student.reload
    assert @student.archived?
    assert_not_nil @student.archived_at
    assert_equal "Só faz crossfit (sem musculação)", @student.archive_reason
  end

  test "create archives without a reason when none is given" do
    sign_in_as(@user)

    post student_archive_path(@student)

    assert_redirected_to student_path(@student)
    @student.reload
    assert @student.archived?
    assert_nil @student.archive_reason
  end

  test "create on an already-archived student redirects with alert and does not change archived_at" do
    sign_in_as(@user)
    already_archived = students(:archived_carol)
    original_archived_at = already_archived.archived_at

    post student_archive_path(already_archived), params: { archive: { reason: "Reaproveitando" } }

    assert_redirected_to student_path(already_archived)
    assert_equal "Aluno já está arquivado.", flash[:alert]

    already_archived.reload
    assert_equal original_archived_at.to_i, already_archived.archived_at.to_i
    assert_nil already_archived.archive_reason
  end

  test "create on a student from another organization is scoped out (404)" do
    sign_in_as(@user)
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")

    post student_archive_path(foreign_student), params: { archive: { reason: "qq" } }

    assert_response :not_found
    assert_not foreign_student.reload.archived?
  end
end
