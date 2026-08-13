// Matching for the **Exercise suggestion** autocomplete. Pure — the corpus is
// shipped whole as a prop (`Exercise.suggestions`), so filtering is local and
// works on a phone with no usable gym wifi.
//
// The keys are computed server-side by `Normalizable`; the query is folded by
// `normalizeForSearch`, the one client-side twin of that rule, so the two sides
// can never drift apart.

import { normalizeForSearch } from "@/lib/utils"

// One non-merged Exercise: its canonical name plus the Normalized keys of all
// of its Aliases. Matching runs over the whole alias corpus — trainer phrasing
// the catalog has learned still finds the movement — but what gets inserted is
// always the canonical `name`, so plans converge on one phrasing.
export type ExerciseSuggestion = {
  id: string
  name: string
  keys: string[]
}

export type ExerciseMatch = {
  id: string
  name: string
  // The key that matched, when it is not the canonical name's own key. Shown as
  // secondary text so the trainer understands why the suggestion appeared.
  matchedAlias: string | null
}

const LIMIT = 8

// Prefix matches first, then substring matches, alphabetical (by canonical
// name) within each tier. Returns [] for a blank query.
export function matchExercises(
  suggestions: ExerciseSuggestion[],
  query: string,
  limit: number = LIMIT,
): ExerciseMatch[] {
  const needle = normalizeForSearch(query)
  if (!needle) return []

  const ranked: { match: ExerciseMatch; tier: number; sortKey: string }[] = []

  for (const suggestion of suggestions) {
    const canonicalKey = normalizeForSearch(suggestion.name)
    const tier = bestTier(suggestion.keys, needle)
    if (tier === null) continue

    const key = bestKey(suggestion.keys, needle, tier, canonicalKey)
    ranked.push({
      match: {
        id: suggestion.id,
        name: suggestion.name,
        matchedAlias: key === canonicalKey ? null : key,
      },
      tier,
      sortKey: canonicalKey,
    })
  }

  ranked.sort((a, b) =>
    a.tier !== b.tier ? a.tier - b.tier : a.sortKey.localeCompare(b.sortKey),
  )

  return ranked.slice(0, limit).map((entry) => entry.match)
}

// 0 when some key starts with the query, 1 when some key merely contains it,
// null when none does.
function bestTier(keys: string[], needle: string): number | null {
  let tier: number | null = null
  for (const key of keys) {
    if (key.startsWith(needle)) return 0
    if (key.includes(needle)) tier = 1
  }
  return tier
}

// The key to attribute the match to. The canonical name wins whenever it
// matches at the same tier, so a suggestion only carries secondary text when an
// alias is genuinely what brought it up.
function bestKey(
  keys: string[],
  needle: string,
  tier: number,
  canonicalKey: string,
): string {
  const matching = keys
    .filter((key) => (tier === 0 ? key.startsWith(needle) : key.includes(needle)))
    .sort()
  return matching.includes(canonicalKey) ? canonicalKey : matching[0]
}
