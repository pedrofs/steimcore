# The single definition of the **Normalized key** — accent-stripped, lowercased,
# trimmed, whitespace-collapsed. Shared by `ExerciseLoad` (per-student weight
# history) and the Exercise catalog (`Exercise::Alias` resolution) so the two
# identities can never drift apart. Mirrors the client-side `normalizeForSearch`
# (NFD + strip combining marks), which is what silently consolidates weight
# history and catalog resolution onto the same key.
module Normalizable
  extend ActiveSupport::Concern

  class_methods do
    # Folds a movement name to its normalized key. Exposed on every includer so
    # call sites read as `Model.normalize_name(value)`.
    def normalize_name(name)
      Normalizable.normalize_key(name)
    end
  end

  def self.normalize_key(name)
    string = name.to_s
    string = string.dup.force_encoding(Encoding::UTF_8) unless string.encoding == Encoding::UTF_8
    string = string.scrub("") unless string.valid_encoding?

    string.unicode_normalize(:nfd)
          .gsub(/\p{Mn}/, "")
          .downcase
          .strip
          .gsub(/\s+/, " ")
  end
end
