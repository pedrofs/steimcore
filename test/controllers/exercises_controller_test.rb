require "test_helper"

class ExercisesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "index redirects unauthenticated visitors to sign in" do
    get exercises_path
    assert_redirected_to new_session_path
  end

  test "index lists every exercise with family, muscle group and state" do
    family = Exercise::Family.create!(name: "Supino", normalized_key: "supino")
    muscle = Exercise::MuscleGroup.create!(name: "Peito", normalized_key: "peito")
    Exercise.create!(name: "Supino reto", exercise_family: family, muscle_group: muscle)
    Exercise.create!(name: "Agachamento")

    sign_in_as(@user)
    get exercises_path

    assert_response :success
    assert_equal "exercises/index", inertia.component
    rows = inertia.props[:exercises].index_by { |e| e[:name] }
    assert_equal "Supino", rows["Supino reto"][:family]
    assert_equal "Peito", rows["Supino reto"][:muscle_group]
    assert_equal "unenriched", rows["Supino reto"][:state]
    assert_includes rows.keys, "Agachamento"
  end

  test "index is global — the same catalog is visible to any trainer" do
    Exercise.create!(name: "Remada")

    sign_in_as(users(:two))
    get exercises_path

    names = inertia.props[:exercises].map { |e| e[:name] }
    assert_includes names, "Remada"
  end

  test "index filters by state" do
    Exercise.create!(name: "Sem mídia")
    enriched = Exercise.create!(name: "Com mídia")
    enriched.enrich(media: [ fixture_file_upload("exercise.png", "image/png") ])

    sign_in_as(@user)
    get exercises_path, params: { state: "enriched" }

    names = inertia.props[:exercises].map { |e| e[:name] }
    assert_includes names, "Com mídia"
    assert_not_includes names, "Sem mídia"
    assert_equal "enriched", inertia.props[:filters][:state]
  end

  test "index ignores unknown state values" do
    sign_in_as(@user)
    get exercises_path, params: { state: "bogus" }

    assert_nil inertia.props[:filters][:state]
  end

  test "index searches by display name and by alias" do
    target = Exercise.create!(name: "Supino reto")
    target.aliases.create!(raw_name: "supino com barra", normalized_key: "supino com barra", source: "llm")
    Exercise.create!(name: "Leg press")

    sign_in_as(@user)
    get exercises_path, params: { q: "barra" }

    names = inertia.props[:exercises].map { |e| e[:name] }
    assert_equal [ "Supino reto" ], names
    assert_equal "barra", inertia.props[:filters][:q]
  end

  test "index escapes LIKE wildcards in the q parameter" do
    Exercise.create!(name: "Rosca 100%")
    Exercise.create!(name: "Tríceps")

    sign_in_as(@user)
    get exercises_path, params: { q: "%" }

    names = inertia.props[:exercises].map { |e| e[:name] }
    assert_includes names, "Rosca 100%"
    assert_not_includes names, "Tríceps"
  end

  test "index paginates at 25 per page and exposes pagination metadata" do
    30.times { |i| Exercise.create!(name: "Ex #{format('%02d', i)}") }

    sign_in_as(@user)
    get exercises_path

    assert_equal 25, inertia.props[:exercises].length
    pagination = inertia.props[:pagination]
    assert_equal 1, pagination[:page]
    assert_equal 30, pagination[:count]
    assert_equal 2, pagination[:next]
  end

  test "index redirects page overflow to the last valid page" do
    30.times { |i| Exercise.create!(name: "Ex #{format('%02d', i)}") }

    sign_in_as(@user)
    get exercises_path, params: { page: 99_999 }

    assert_redirected_to exercises_path(page: 2)
  end

  test "show renders the exercise detail" do
    exercise = Exercise.create!(name: "Remada curvada")

    sign_in_as(@user)
    get exercise_path(exercise)

    assert_response :success
    assert_equal "exercises/show", inertia.component
    assert_equal exercise.id, inertia.props[:exercise][:id]
    assert_equal "Remada curvada", inertia.props[:exercise][:aliases].first[:raw_name]
  end

  test "edit renders the enrichment form" do
    exercise = Exercise.create!(name: "Remada curvada")

    sign_in_as(@user)
    get edit_exercise_path(exercise)

    assert_response :success
    assert_equal "exercises/edit", inertia.component
    assert_equal exercise.id, inertia.props[:exercise][:id]
  end

  test "update attaches media, confirms taxonomy and flips state to enriched" do
    exercise = Exercise.create!(name: "Remada curvada")

    sign_in_as(@user)
    patch exercise_path(exercise), params: {
      exercise: {
        exercise_family_name: "Remada",
        muscle_group_name: "Costas",
        media: [ fixture_file_upload("exercise.png", "image/png") ]
      }
    }

    assert_redirected_to exercise_path(exercise)
    assert_equal "Exercício atualizado.", flash[:notice]
    exercise.reload
    assert_predicate exercise, :enriched?
    assert exercise.media.attached?
    assert_equal "Remada", exercise.exercise_family.name
    assert_equal "Costas", exercise.muscle_group.name
  end

  test "update without media saves taxonomy but stays unenriched" do
    exercise = Exercise.create!(name: "Remada curvada")

    sign_in_as(@user)
    patch exercise_path(exercise), params: {
      exercise: { exercise_family_name: "Remada", muscle_group_name: "Costas" }
    }

    assert_redirected_to exercise_path(exercise)
    exercise.reload
    assert_predicate exercise, :unenriched?
    assert_equal "Remada", exercise.exercise_family.name
  end

  test "update reuses an existing taxonomy node by normalized key" do
    family = Exercise::Family.create!(name: "Remada", normalized_key: "remada")
    exercise = Exercise.create!(name: "Remada baixa")

    sign_in_as(@user)
    assert_no_difference -> { Exercise::Family.count } do
      patch exercise_path(exercise), params: {
        exercise: { exercise_family_name: "  REMADA  ", muscle_group_name: "" }
      }
    end

    assert_equal family.id, exercise.reload.exercise_family_id
    assert_nil exercise.muscle_group_id
  end
end
