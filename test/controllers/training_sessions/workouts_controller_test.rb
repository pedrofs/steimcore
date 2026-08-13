require "test_helper"

class TrainingSessions::WorkoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:steimfit)
    @user = users(:one)
    @alice = students(:alice)
    @workouts = make_eligible(@alice, workout_count: 2)
    @session = @user.training_sessions.start_for!(@alice)
  end

  test "update requires authentication" do
    patch training_session_workout_path(@session), params: revision_params, as: :json

    assert_redirected_to new_session_path
  end

  test "update revises the plan and redirects with a plan-level notice" do
    sign_in_as(@user)
    periodization = @alice.active_periodization

    assert_difference -> { periodization.versions.count }, 1 do
      patch training_session_workout_path(@session), params: revision_params, as: :json
    end

    assert_redirected_to training_sessions_path
    assert_equal "Treino atualizado no plano do aluno.", flash[:notice]

    new_version = periodization.reload.current_version
    assert_equal "completed", new_version.status
    assert_equal revised_blocks, @session.reload.blocks_snapshot
    assert_equal new_version.id, @session.periodization_version_id
  end

  test "update remaps progress across the edit, treating a blank origin as a new block" do
    sign_in_as(@user)
    @session.update!(progress: [ "0" ])

    patch training_session_workout_path(@session),
          params: revision_params(origin_indices: [ "", 0 ], blocks: [ new_block, revised_blocks.first ]),
          as: :json

    assert_equal [ "1" ], @session.reload.progress
  end

  test "update allows another trainer in the same organization to revise" do
    sign_in_as(users(:two))

    patch training_session_workout_path(@session), params: revision_params, as: :json

    assert_redirected_to training_sessions_path
    assert_equal revised_blocks, @session.reload.blocks_snapshot
  end

  test "update rejects a finished session with a pt-BR alert and forks nothing" do
    sign_in_as(@user)
    @session.update!(finished_at: Time.current)
    periodization = @alice.active_periodization

    assert_no_difference -> { periodization.versions.count } do
      patch training_session_workout_path(@session), params: revision_params, as: :json
    end

    assert_redirected_to training_sessions_path
    assert_equal "Esta sessão já foi finalizada e não pode ser editada.", flash[:alert]
  end

  test "update rejects a detached session with a pt-BR alert and forks nothing" do
    sign_in_as(@user)
    digest = @session.blocks_digest
    @session.update_columns(workout_id: nil)
    periodization = @alice.active_periodization

    assert_no_difference -> { periodization.versions.count } do
      patch training_session_workout_path(@session), params: revision_params(blocks_digest: digest), as: :json
    end

    assert_redirected_to training_sessions_path
    assert_equal "O plano deste aluno mudou desde o início da sessão. Recarregue a página.", flash[:alert]
  end

  test "update rejects a stale blocks digest with a pt-BR alert and forks nothing" do
    sign_in_as(@user)
    periodization = @alice.active_periodization

    assert_no_difference -> { periodization.versions.count } do
      patch training_session_workout_path(@session),
            params: revision_params(blocks_digest: "outra-coisa"),
            as: :json
    end

    assert_redirected_to training_sessions_path
    assert_equal "Este treino foi alterado por outra pessoa. Recarregue a página e tente novamente.", flash[:alert]
    assert_not_equal revised_blocks, @session.reload.blocks_snapshot
  end

  test "update rejects invalid blocks with pt-BR errors and forks nothing" do
    sign_in_as(@user)
    periodization = @alice.active_periodization

    assert_no_difference -> { periodization.versions.count } do
      patch training_session_workout_path(@session),
            params: revision_params(blocks: [ { kind: "exercise", name: "", prescription: "" } ]),
            as: :json
    end

    assert_redirected_to training_sessions_path
    errors = (session[:inertia_errors] || {}).values.flatten
    assert_equal [ "bloco 0: name ausente ou vazio", "bloco 0: prescription ausente ou vazia" ], errors
  end

  test "update rejects a payload with no blocks key instead of emptying the workout" do
    sign_in_as(@user)
    periodization = @alice.active_periodization

    assert_no_difference -> { periodization.versions.count } do
      patch training_session_workout_path(@session),
            params: { origin_indices: [], blocks_digest: @session.blocks_digest },
            as: :json
    end

    assert_response :bad_request
  end

  test "update rejects a trainer from a different organization with 404" do
    other_org  = Organization.create!(name: "Other Gym", equipment_list_md: "")
    other_user = User.create!(email_address: "other@example.com", password: "password", organization: other_org)
    sign_in_as(other_user)

    patch training_session_workout_path(@session), params: revision_params, as: :json

    assert_response :not_found
    assert_not_equal revised_blocks, @session.reload.blocks_snapshot
  end

  private
    def revised_blocks
      [ { "kind" => "exercise", "name" => "Hack squat", "prescription" => "4x8", "rest_s" => 90 } ]
    end

    def new_block
      { "kind" => "freeform", "text_md" => "Alongar no fim" }
    end

    def revision_params(blocks: nil, origin_indices: [ 0 ], blocks_digest: nil)
      {
        workout: { blocks: blocks || revised_blocks },
        origin_indices: origin_indices,
        blocks_digest: blocks_digest || @session.blocks_digest
      }
    end

    def make_eligible(student, workout_count:)
      version = student.start_periodization!(trainer: @user)
      workouts = Array.new(workout_count) do |i|
        version.workouts.create!(
          name: "Treino #{i + 1}",
          position: i + 1,
          blocks: [ { "kind" => "exercise", "name" => "Ex #{i + 1}", "prescription" => "3x10" } ]
        )
      end
      version.periodization_length_weeks = 8
      version.complete!
      student.active_periodization.set_current_version!(version)
      workouts
    end
end
