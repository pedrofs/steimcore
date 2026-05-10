require "test_helper"

class Students::PeriodizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @organization = @user.organization
    @student = students(:alice)
  end

  test "new redirects to the voice recording flow with kind=periodization_create" do
    sign_in_as(@user)

    get new_student_periodization_path(@student)

    assert_redirected_to new_student_voice_recording_path(@student, kind: "periodization_create")
  end

  test "new is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    sign_in_as(@user)

    get new_student_periodization_path(foreign_student)

    assert_response :not_found
  end

  test "show renders the active periodization with body and workouts" do
    recording = VoiceRecording.create!(
      organization: @organization,
      student: @student,
      trainer: @user,
      kind: "periodization_create"
    )
    version = @student.start_periodization!(trainer: @user, voice_recording: recording)
    version.fork_with!(
      scope: :create,
      patch: {
        body_md: "## Plano",
        workouts: [
          { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 },
          { name: "B", blocks: [ exercise_block("Supino", "4x8") ], position: 2 }
        ]
      },
      trainer: @user,
      voice_recording: recording
    )
    version.transition_to!(:completed)
    periodization = version.periodization
    periodization.update!(current_version: version)

    sign_in_as(@user)
    get student_periodization_path(@student, periodization)

    assert_response :success
    assert_equal "students/periodizations/show", inertia.component
    props = inertia.props[:periodization]
    assert_equal periodization.id, props[:id]
    assert_equal "## Plano", props[:current_version][:body_md]
    assert_equal %w[A B], props[:current_version][:workouts].map { |w| w[:name] }
    assert_equal "exercise", props[:current_version][:workouts].first[:blocks].first["kind"]
  end

  test "show is scoped to the current organization" do
    other_org = Organization.create!(name: "Outro Gym")
    foreign_student = other_org.students.create!(name: "Externo")
    foreign_periodization = foreign_student.periodizations.create!
    sign_in_as(@user)

    get student_periodization_path(foreign_student, foreign_periodization)

    assert_response :not_found
  end

  test "show includes completed versions in chronological order with authoring trainer, marking the current version" do
    other_trainer = User.create!(email_address: "outro@example.com", password: "password", organization: @organization)

    rec_v1 = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: @user,
      kind: "periodization_create"
    )
    v1 = @student.start_periodization!(trainer: @user, voice_recording: rec_v1)
    v1.fork_with!(scope: :create, patch: { body_md: "## v1", workouts: [
      { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 }
    ] }, trainer: @user, voice_recording: rec_v1)
    v1.transition_to!(:completed)
    periodization = v1.periodization
    periodization.set_current_version!(v1)

    rec_v1.update!(transcript: "Primeira versão: foco em hipertrofia para o aluno teste.")

    rec_v2 = VoiceRecording.create!(
      organization: @organization, student: @student, trainer: other_trainer,
      kind: "periodization_edit_periodization",
      transcript: "Adicionar treino C para o membro inferior."
    )
    v2 = periodization.start_edit!(scope: :periodization, trainer: other_trainer, voice_recording: rec_v2)
    v2.fork_with!(scope: :periodization, patch: { body_md: "## v2", workouts: [
      { name: "A", blocks: [ exercise_block("Agachamento", "4x8") ], position: 1 },
      { name: "C", blocks: [ exercise_block("Leg press", "4x10") ], position: 2 }
    ] }, trainer: other_trainer, voice_recording: rec_v2)
    v2.transition_to!(:completed)
    periodization.set_current_version!(v2)

    pending_version = periodization.versions.create!(trainer: @user, parent_version: v2)
    pending_version.transition_to!(:generating)
    failed_version = periodization.versions.create!(trainer: @user, parent_version: v2)
    failed_version.transition_to!(:generating)
    failed_version.fail!("erro")

    sign_in_as(@user)
    get student_periodization_path(@student, periodization)

    assert_response :success
    versions = inertia.props[:periodization][:versions]
    assert_equal [ v1.id, v2.id ], versions.map { |v| v[:id] }
    assert_equal [ @user.email_address, other_trainer.email_address ], versions.map { |v| v[:trainer][:email] }
    assert_equal [ false, true ], versions.map { |v| v[:current] }
    assert_equal "Primeira versão: foco em hipertrofia para o aluno teste.", versions.first[:transcript_excerpt]
  end

  private
    def exercise_block(name, prescription)
      { "kind" => "exercise", "name" => name, "prescription" => prescription }
    end
end
