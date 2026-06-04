require "test_helper"

class Exercise::FamilyTest < ActiveSupport::TestCase
  test "for_name creates a family keyed on the normalized name" do
    family = Exercise::Family.for_name("  Supino Reto ")

    assert family.persisted?
    assert_equal "Supino Reto", family.name
    assert_equal "supino reto", family.normalized_key
  end

  test "for_name reuses an existing family across accent/case/whitespace variants" do
    existing = Exercise::Family.create!(name: "Supino", normalized_key: "supino")

    assert_no_difference -> { Exercise::Family.count } do
      assert_equal existing, Exercise::Family.for_name("  SÚPINO  ")
    end
  end

  test "for_name returns nil for a blank name" do
    assert_nil Exercise::Family.for_name("   ")
    assert_nil Exercise::Family.for_name(nil)
  end
end
