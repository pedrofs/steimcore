require "test_helper"

class ExerciseUploadQueuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    periodization = students(:alice).periodizations.create!
    @version = periodization.versions.create!(trainer: @user, parent_version: nil)
  end

  test "show requires authentication" do
    get exercise_upload_queue_path
    assert_redirected_to new_session_path
  end

  test "show lists unenriched referenced exercises ranked by usage with their counts" do
    heavy = Exercise.create!(name: "Supino reto")
    light = Exercise.create!(name: "Stiff")
    Exercise.create!(name: "Órfão") # unreferenced — must not appear
    @version.workouts.create!(name: "A", position: 1, blocks: [
      { "kind" => "exercise", "name" => "Supino reto", "prescription" => "4x8" },
      { "kind" => "exercise", "name" => "Supino reto", "prescription" => "3x10" },
      { "kind" => "exercise", "name" => "Stiff", "prescription" => "3x12" }
    ])

    sign_in_as(@user)
    get exercise_upload_queue_path

    assert_response :success
    assert_equal "exercise_upload_queue/show", inertia.component

    items = inertia.props[:exercises]
    assert_equal [ heavy.id, light.id ], items.map { |item| item[:id] }
    assert_equal 2, items.first[:usage_count]
    assert_equal "Supino reto", items.first[:name]
  end
end
