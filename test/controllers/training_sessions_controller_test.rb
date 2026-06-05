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

  test "index org scope renders a trainer-less session with null trainer fields and no error" do
    make_eligible(@alice, workout_count: 1)
    self_serve = TrainingSession.start!(student: @alice)

    sign_in_as(@user)
    get training_sessions_path, params: { scope: "org" }

    assert_response :success
    payload = inertia.props[:training_sessions].find { |s| s[:id] == self_serve.id }
    assert_not_nil payload
    assert_nil payload[:trainer_id]
    assert_nil payload[:trainer_name]
  end

  test "trainer scope excludes trainer-less self-serve sessions" do
    make_eligible(@alice, workout_count: 1)
    self_serve = TrainingSession.start!(student: @alice)

    sign_in_as(@user)
    get training_sessions_path

    ids = inertia.props[:training_sessions].map { |s| s[:id] }
    assert_not_includes ids, self_serve.id
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

  test "backdated create logs a finished session on the given past date" do
    workouts = make_eligible(@alice, workout_count: 2)
    sign_in_as(@user)
    on_date = Date.current - 3

    assert_difference -> { TrainingSession.count }, 1 do
      post training_sessions_path,
           params: { student_id: @alice.id, for_date: on_date.iso8601, workout_id: workouts.last.id },
           headers: { "Referer" => student_url(@alice) }
    end

    assert_redirected_to student_url(@alice)
    session = TrainingSession.order(created_at: :desc).first
    assert_equal workouts.last.id, session.workout_id
    assert_equal on_date, session.created_at.in_time_zone.to_date
    assert_not_nil session.finished_at
  end

  test "backdated create rejects future dates" do
    workouts = make_eligible(@alice, workout_count: 1)
    sign_in_as(@user)

    assert_no_difference -> { TrainingSession.count } do
      post training_sessions_path,
           params: { student_id: @alice.id, for_date: (Date.current + 1).iso8601, workout_id: workouts.first.id },
           headers: { "Referer" => student_url(@alice) }
    end

    follow_redirect!
    assert_match(/futura/i, flash[:alert] || "")
  end

  test "backdated create rejects a workout that is not part of the student's current version" do
    make_eligible(@alice, workout_count: 1)
    other_workouts = make_eligible(@bob, workout_count: 1)
    sign_in_as(@user)

    assert_no_difference -> { TrainingSession.count } do
      post training_sessions_path,
           params: { student_id: @alice.id, for_date: Date.current.iso8601, workout_id: other_workouts.first.id },
           headers: { "Referer" => student_url(@alice) }
    end

    follow_redirect!
    assert_match(/periodiza/i, flash[:alert] || "")
  end

  test "destroy removes the session and redirects back" do
    make_eligible(@alice, workout_count: 1)
    session = @user.training_sessions.start_for!(@alice)
    sign_in_as(@user)

    assert_difference -> { TrainingSession.count }, -1 do
      delete training_session_path(session), headers: { "Referer" => training_sessions_url }
    end

    assert_redirected_to training_sessions_url
  end

  test "destroy is org-scoped" do
    make_eligible(@alice, workout_count: 1)
    session = @user.training_sessions.start_for!(@alice)

    other_org   = Organization.create!(name: "Other Gym", equipment_list_md: "")
    other_user  = User.create!(email_address: "other@example.com", password: "password", organization: other_org)
    sign_in_as(other_user)

    assert_no_difference -> { TrainingSession.count } do
      delete training_session_path(session)
    end
    assert_response :not_found
  end

  test "index enriches focused-session blocks with exercise media" do
    exercise = Exercise.create!(name: "Supino Reto")
    exercise.media.attach(io: StringIO.new("png-bytes"), filename: "photo.png", content_type: "image/png")
    make_eligible(@alice, workout_count: 1, blocks: [
      { "kind" => "exercise", "name" => "Supino Reto", "prescription" => "4x10" },
      { "kind" => "group", "label" => "Bíceps", "items" => [
        { "name" => "Supino Reto", "prescription" => "3x12" }
      ] }
    ])
    @user.training_sessions.start_for!(@alice)

    sign_in_as(@user)
    get training_sessions_path

    blocks = inertia.props[:training_sessions].first[:blocks]
    assert_equal 1, blocks[0]["media"].size, "exercise block carries media"
    assert_equal 1, blocks[1]["items"][0]["media"].size, "group item carries media"
  end

  test "index enriches a student-initiated session viewed under org scope" do
    exercise = Exercise.create!(name: "Agachamento")
    exercise.media.attach(io: StringIO.new("png-bytes"), filename: "photo.png", content_type: "image/png")
    make_eligible(@alice, workout_count: 1, blocks: [
      { "kind" => "exercise", "name" => "Agachamento", "prescription" => "5x5" }
    ])
    @alice.start_training_session!

    sign_in_as(@user)
    get training_sessions_path, params: { scope: "org" }

    blocks = inertia.props[:training_sessions].first[:blocks]
    assert_equal 1, blocks[0]["media"].size
  end

  private
    def make_eligible(student, workout_count:, blocks: [], trainer: @user, organization: @organization)
      version = student.start_periodization!(trainer: trainer)
      workouts = Array.new(workout_count) do |i|
        version.workouts.create!(name: "Treino #{i + 1}", position: i + 1, blocks: blocks)
      end
      version.periodization_length_weeks = 8
      version.complete!
      student.active_periodization.set_current_version!(version)
      workouts
    end
end
