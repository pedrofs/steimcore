class AddTrigramIndexToExerciseAliases < ActiveRecord::Migration[8.2]
  def change
    enable_extension "pg_trgm"

    # GIN trigram index over the alias corpus so `Exercise::Alias.candidates_for`
    # can recall fuzzy matches via the `%` similarity operator. The Normalized key
    # is already accent-stripped in Ruby, so no `unaccent` is needed.
    add_index :exercise_aliases, :normalized_key,
              using: :gin, opclass: :gin_trgm_ops,
              name: "index_exercise_aliases_on_normalized_key_trgm"
  end
end
