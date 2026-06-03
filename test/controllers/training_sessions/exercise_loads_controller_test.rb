require "test_helper"

class TrainingSessions::ExerciseLoadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @alice = students(:alice)
    @workouts = make_eligible(@alice, workout_count: 1, blocks: three_exercise_blocks)
    @session = @user.training_sessions.start_for!(@alice)
  end

  test "create requires authentication" do
    post training_session_exercise_loads_path(@session),
         params: { exercise_name: "Agachamento", value: "80kg" }

    assert_redirected_to new_session_path
  end

  test "create records the weight and redirects back" do
    sign_in_as(@user)

    post training_session_exercise_loads_path(@session),
         params: { exercise_name: "Agachamento", value: "80kg" }

    assert_redirected_to training_sessions_path
    assert_equal "80kg", @alice.reload.current_load_for("Agachamento")
  end

  test "create rejects a blank value with a flash alert" do
    sign_in_as(@user)

    post training_session_exercise_loads_path(@session),
         params: { exercise_name: "Agachamento", value: "" }

    assert_redirected_to training_sessions_path
    assert_equal 0, @alice.exercise_loads.count
  end

  test "create allows another trainer in the same organization" do
    sign_in_as(users(:two))

    post training_session_exercise_loads_path(@session),
         params: { exercise_name: "Agachamento", value: "80kg" }

    assert_redirected_to training_sessions_path
    assert_equal "80kg", @alice.reload.current_load_for("Agachamento")
  end

  test "create rejects a trainer from a different organization with 404" do
    other_org  = Organization.create!(name: "Other Gym", equipment_list_md: "")
    other_user = User.create!(email_address: "other@example.com", password: "password", organization: other_org)
    sign_in_as(other_user)

    post training_session_exercise_loads_path(@session),
         params: { exercise_name: "Agachamento", value: "80kg" }

    assert_response :not_found
    assert_equal 0, @alice.reload.exercise_loads.count
  end

  private
    def make_eligible(student, workout_count:, blocks: [])
      version = student.start_periodization!(trainer: @user)
      workouts = Array.new(workout_count) do |i|
        version.workouts.create!(name: "Treino #{i + 1}", position: i + 1, blocks: blocks)
      end
      version.periodization_length_weeks = 8
      version.complete!
      student.active_periodization.set_current_version!(version)
      workouts
    end

    def three_exercise_blocks
      [
        { "kind" => "exercise", "name" => "Agachamento", "prescription" => "3x10" },
        { "kind" => "exercise", "name" => "Supino",      "prescription" => "3x8" },
        { "kind" => "exercise", "name" => "Remada",      "prescription" => "3x12" }
      ]
    end
end
