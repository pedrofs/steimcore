require "test_helper"

class NormalizableTest < ActiveSupport::TestCase
  test "strips accents, lowercases, trims and collapses whitespace" do
    assert_equal "supino reto", Normalizable.normalize_key("  Supíno   Reto ")
    assert_equal "supino reto", Normalizable.normalize_key("SUPINO RETO")
    assert_equal "rosca direta", Normalizable.normalize_key("Rosca Diréta")
  end

  test "nil and blank fold to an empty string" do
    assert_equal "", Normalizable.normalize_key(nil)
    assert_equal "", Normalizable.normalize_key("   ")
  end

  test "is idempotent" do
    once = Normalizable.normalize_key("  Agachamento  Búlgaro ")
    assert_equal once, Normalizable.normalize_key(once)
  end

  test "scrubs invalid encoding instead of raising" do
    bad = "caf\xC3".dup.force_encoding(Encoding::UTF_8)
    assert_nothing_raised { Normalizable.normalize_key(bad) }
  end

  test "exposes normalize_name on includers identical to the module" do
    [ "Supíno Reto", "SUPINO RETO", "  ", nil ].each do |raw|
      assert_equal Normalizable.normalize_key(raw), ExerciseLoad.normalize_name(raw)
    end
  end
end
