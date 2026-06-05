require "test_helper"

class Exercises::MediaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "create requires authentication" do
    exercise = Exercise.create!(name: "Supino reto")

    post exercise_media_path(exercise), params: { media: signed_clip }

    assert_redirected_to new_session_path
    assert_not exercise.reload.media.attached?
  end

  test "create attaches the captured clip, enriches the exercise, and redirects to the queue" do
    exercise = Exercise.create!(name: "Supino reto")

    sign_in_as(@user)
    post exercise_media_path(exercise), params: { media: signed_clip }

    assert_redirected_to exercise_upload_queue_path
    assert_predicate exercise.reload, :enriched?
    assert exercise.media.attached?
  end

  test "create is a no-op when the exercise already has media" do
    exercise = Exercise.create!(name: "Supino reto")
    exercise.update!(state: :enriched)

    sign_in_as(@user)
    post exercise_media_path(exercise), params: { media: signed_clip }

    assert_redirected_to exercise_upload_queue_path
    assert_not exercise.reload.media.attached?
  end

  test "create cannot target a merged-away exercise" do
    survivor = Exercise.create!(name: "Supino")
    merged = Exercise.create!(name: "Supino reto")
    merged.update!(merged_into: survivor)

    sign_in_as(@user)
    post exercise_media_path(merged), params: { media: signed_clip }

    assert_response :not_found
    assert_not merged.reload.media.attached?
  end

  private
    # The browser direct-uploads the clip first and posts only the resulting blob's
    # signed_id; mirror that here by minting a blob and handing over its signed_id.
    def signed_clip
      ActiveStorage::Blob.create_and_upload!(
        io: file_fixture("exercise.png").open,
        filename: "exercise.png",
        content_type: "image/png"
      ).signed_id
    end
end
