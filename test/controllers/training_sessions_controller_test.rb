require "test_helper"

class TrainingSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:steimfit)
    @user = users(:one)
    @alice = students(:alice)
    @bob = students(:bob)
  end

  test "index redirects unauthenticated visitors to sign in" do
    get training_sessions_path
    assert_redirected_to new_session_path
  end

  test "index renders the empty-state component with three props" do
    sign_in_as(@user)

    get training_sessions_path

    assert_response :success
    assert_equal "training_sessions/index", inertia.component
    assert_equal [], inertia.props[:training_sessions]
    assert_kind_of Array, inertia.props[:picker_candidates]
    assert_equal "trainer", inertia.props[:scope]
  end

  test "index defaults scope to trainer when ?scope is missing or unrecognized" do
    sign_in_as(@user)

    get training_sessions_path
    assert_equal "trainer", inertia.props[:scope]

    get training_sessions_path, params: { scope: "garbage" }
    assert_equal "trainer", inertia.props[:scope]
  end

  test "index resolves scope=org and returns all active org sessions ordered by created_at ASC" do
    make_eligible(@alice, workout_count: 1)
    make_eligible(@bob, workout_count: 1)
    user_two = users(:two)
    my_session    = @user.training_sessions.start_for!(@alice)
    other_session = user_two.training_sessions.start_for!(@bob)
    my_session.update_columns(created_at: 1.hour.ago)

    sign_in_as(@user)
    get training_sessions_path, params: { scope: "org" }

    assert_equal "org", inertia.props[:scope]
    ids = inertia.props[:training_sessions].map { |s| s[:id] }
    assert_equal [ my_session.id, other_session.id ], ids
  end

  test "index in trainer scope only returns the current trainer's sessions" do
    make_eligible(@alice, workout_count: 1)
    make_eligible(@bob, workout_count: 1)
    user_two = users(:two)
    my_session    = @user.training_sessions.start_for!(@alice)
    _other        = user_two.training_sessions.start_for!(@bob)

    sign_in_as(@user)
    get training_sessions_path

    ids = inertia.props[:training_sessions].map { |s| s[:id] }
    assert_equal [ my_session.id ], ids
  end

  test "index never includes sessions from other organizations even in org scope" do
    make_eligible(@alice, workout_count: 1)
    @user.training_sessions.start_for!(@alice)

    other_org      = Organization.create!(name: "Other Gym", equipment_list_md: "")
    other_user     = User.create!(email_address: "other@example.com", password: "password", organization: other_org)
    other_student  = Student.create!(name: "Other Student", organization: other_org)
    make_eligible(other_student, workout_count: 1, trainer: other_user, organization: other_org)
    other_user.training_sessions.start_for!(other_student)

    sign_in_as(@user)
    get training_sessions_path, params: { scope: "org" }

    student_ids = inertia.props[:training_sessions].map { |s| s[:student][:id] }
    assert_includes student_ids, @alice.id
    assert_not_includes student_ids, other_student.id
  end

  test "index session payload exposes trainer_id and trainer_name" do
    make_eligible(@alice, workout_count: 1)
    @user.training_sessions.start_for!(@alice)

    sign_in_as(@user)
    get training_sessions_path

    payload = inertia.props[:training_sessions].first
    assert_equal @user.id, payload[:trainer_id]
    assert_equal @user.email_address.split("@").first, payload[:trainer_name]
  end

  test "active_session_count shared prop always reflects the current trainer regardless of scope" do
    make_eligible(@alice, workout_count: 1)
    make_eligible(@bob, workout_count: 1)
    user_two = users(:two)
    @user.training_sessions.start_for!(@alice)
    user_two.training_sessions.start_for!(@bob)

    sign_in_as(@user)
    get training_sessions_path, params: { scope: "org" }

    assert_equal 1, inertia.props[:active_session_count]
  end

  test "index serializes the current trainer's active sessions ordered by created_at ASC" do
    make_eligible(@alice, workout_count: 1)
    make_eligible(@bob, workout_count: 1)
    older = @user.training_sessions.start_for!(@alice)
    older.update_columns(created_at: 1.hour.ago)
    newer = @user.training_sessions.start_for!(@bob)

    sign_in_as(@user)
    get training_sessions_path

    ids = inertia.props[:training_sessions].map { |s| s[:id] }
    assert_equal [ older.id, newer.id ], ids

    first = inertia.props[:training_sessions].first
    assert_equal @alice.id, first[:student][:id]
    assert_equal @alice.name, first[:student][:name]
    assert_equal older.workout_name_snapshot, first[:workout_name]
    assert_equal older.workout_position_snapshot, first[:workout_position]
    assert_equal older.blocks_snapshot, first[:blocks]
    assert_equal [], first[:completed_block_indices]
    assert_nil first[:finished_at]
    assert_not_nil first[:created_at]
    assert_equal @user.id, first[:trainer_id]
  end

  test "index lists eligible students in picker_candidates with eligible flag" do
    make_eligible(@alice, workout_count: 2)

    sign_in_as(@user)
    get training_sessions_path

    candidates = inertia.props[:picker_candidates]
    alice = candidates.find { |c| c[:id] == @alice.id }
    assert alice[:eligible]
    assert_nil alice[:ineligible_reason]
  end

  test "picker_candidates marks students who already have an active session with already_active reason" do
    make_eligible(@alice, workout_count: 1)
    @user.training_sessions.start_for!(@alice)

    sign_in_as(@user)
    get training_sessions_path

    candidates = inertia.props[:picker_candidates]
    alice = candidates.find { |c| c[:id] == @alice.id }
    assert_not alice[:eligible]
    assert_equal "already_active", alice[:ineligible_reason]
  end

  test "picker_candidates marks a student whose current version is not completed with generating reason" do
    make_eligible(@alice, workout_count: 1)
    @alice.active_periodization.current_version.update_columns(status: "generating")

    sign_in_as(@user)
    get training_sessions_path

    candidates = inertia.props[:picker_candidates]
    alice = candidates.find { |c| c[:id] == @alice.id }
    assert_not alice[:eligible]
    assert_equal "generating", alice[:ineligible_reason]
  end

  test "picker_candidates marks a student with no periodization as no_periodization" do
    sign_in_as(@user)
    get training_sessions_path

    candidates = inertia.props[:picker_candidates]
    bob = candidates.find { |c| c[:id] == @bob.id }
    assert_not bob[:eligible]
    assert_equal "no_periodization", bob[:ineligible_reason]
  end

  test "picker_candidates excludes archived students" do
    make_eligible(@alice, workout_count: 1)
    @alice.archive!

    sign_in_as(@user)
    get training_sessions_path

    candidate_ids = inertia.props[:picker_candidates].map { |c| c[:id] }
    assert_not_includes candidate_ids, @alice.id
  end

  test "picker_candidates marks a student whose periodization has no workouts as no_periodization" do
    make_eligible(@alice, workout_count: 0)

    sign_in_as(@user)
    get training_sessions_path

    candidates = inertia.props[:picker_candidates]
    alice = candidates.find { |c| c[:id] == @alice.id }
    assert_not alice[:eligible]
    assert_equal "no_periodization", alice[:ineligible_reason]
  end

  test "index session payload includes stale flag derived from STALE_CUTOFF" do
    make_eligible(@alice, workout_count: 1)
    make_eligible(@bob, workout_count: 1)
    fresh = @user.training_sessions.start_for!(@alice)
    stale_session = @user.training_sessions.start_for!(@bob)
    stale_session.update_columns(created_at: (TrainingSession::Finishable::STALE_CUTOFF + 1.hour).ago)

    sign_in_as(@user)
    get training_sessions_path

    payloads = inertia.props[:training_sessions].index_by { |s| s[:id] }
    assert_not payloads[fresh.id][:stale]
    assert payloads[stale_session.id][:stale]
  end

  test "create starts a session for an eligible student and redirects back" do
    workouts = make_eligible(@alice, workout_count: 1)
    sign_in_as(@user)

    assert_difference -> { TrainingSession.count }, 1 do
      post training_sessions_path, params: { student_id: @alice.id }
    end

    assert_redirected_to training_sessions_path
    session = TrainingSession.find_by(student_id: @alice.id)
    assert_equal @user.id, session.trainer_id
    assert_equal workouts.first.id, session.workout_id
    assert_equal workouts.first.name, session.workout_name_snapshot
  end

  test "create redirects with a flash alert when the student is ineligible" do
    sign_in_as(@user)

    assert_no_difference -> { TrainingSession.count } do
      post training_sessions_path, params: { student_id: @alice.id }
    end

    assert_redirected_to training_sessions_path
    follow_redirect!
    assert_match(/periodiza/i, flash[:alert] || "")
  end

  test "create surfaces the uniqueness conflict toast when the student already has an active session" do
    make_eligible(@alice, workout_count: 1)
    @user.training_sessions.start_for!(@alice)

    sign_in_as(@user)

    assert_no_difference -> { TrainingSession.count } do
      post training_sessions_path, params: { student_id: @alice.id }
    end

    assert_redirected_to training_sessions_path
    follow_redirect!
    assert_match(/em sessão ativa.*Todas/i, flash[:alert] || "")
  end

  private
    def make_eligible(student, workout_count:, blocks: [], trainer: @user, organization: @organization)
      voice_recording = VoiceRecording.create!(
        organization: organization, student: student, trainer: trainer,
        kind: "periodization_create"
      )
      voice_recording.transition_to!(:transcribing)
      voice_recording.update!(transcript: "x")
      voice_recording.transition_to!(:transcribed)
      voice_recording.transition_to!(:generating)

      version = student.start_periodization!(trainer: trainer, voice_recording: voice_recording)
      workouts = Array.new(workout_count) do |i|
        version.workouts.create!(name: "Treino #{i + 1}", position: i + 1, blocks: blocks)
      end
      version.complete!
      student.active_periodization.set_current_version!(version)
      workouts
    end
end
