require "test_helper"

class ExerciseLoadTest < ActiveSupport::TestCase
  test "normalize_name folds case, accents and collapses whitespace" do
    assert_equal "supino reto", ExerciseLoad.normalize_name("  Supíno   Reto ")
    assert_equal "supino reto", ExerciseLoad.normalize_name("SUPINO RETO")
    assert_equal "rosca direta", ExerciseLoad.normalize_name("Rosca Direta")
  end

  test "normalize_name handles nil and blank" do
    assert_equal "", ExerciseLoad.normalize_name(nil)
    assert_equal "", ExerciseLoad.normalize_name("   ")
  end

  test "validations require name, key and value" do
    load = ExerciseLoad.new
    assert_not load.valid?
    assert load.errors[:exercise_name].any?
    assert load.errors[:exercise_key].any?
    assert load.errors[:value].any?
  end
end
