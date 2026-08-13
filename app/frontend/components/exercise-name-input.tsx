// The **Exercise suggestion** combobox: a free-text name field that offers the
// catalog's canonical movements as you type. Used by every Exercise name field
// — the exercise block's and the group item's — on every editing surface.
//
// It stays free text on purpose. A name with no match is perfectly valid, saves
// fine, and gets minted into the catalog by **Linking** once the resulting
// version completes. Picking a suggestion inserts the canonical name, so plans
// converge on one phrasing and **Resolution** (and the media it surfaces) hits
// more often. No Exercise id is ever written into block JSON — resolution is
// read-time (ADR-0006).

import { useId, useMemo, useRef, useState } from "react"

import { Input } from "@/components/ui/input"
import {
  type ExerciseSuggestion,
  matchExercises,
} from "@/lib/exercise-suggestions"
import { cn } from "@/lib/utils"

export function ExerciseNameInput({
  value,
  onChange,
  suggestions = [],
  placeholder,
  "aria-label": ariaLabel,
}: {
  value: string
  onChange: (next: string) => void
  suggestions?: ExerciseSuggestion[]
  placeholder?: string
  "aria-label"?: string
}) {
  const listId = useId()
  const [open, setOpen] = useState(false)
  const [activeIndex, setActiveIndex] = useState(0)
  // Suppresses the list right after a pick, so inserting a canonical name does
  // not immediately re-open it on that same name.
  const justPicked = useRef(false)

  const matches = useMemo(
    () => matchExercises(suggestions, value),
    [suggestions, value],
  )
  const listOpen = open && matches.length > 0

  function pick(name: string) {
    justPicked.current = true
    onChange(name)
    setOpen(false)
  }

  function handleKeyDown(event: React.KeyboardEvent<HTMLInputElement>) {
    if (!listOpen) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      setActiveIndex((current) => (current + 1) % matches.length)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      setActiveIndex((current) => (current - 1 + matches.length) % matches.length)
    } else if (event.key === "Enter") {
      event.preventDefault()
      pick(matches[activeIndex]?.name ?? value)
    } else if (event.key === "Escape") {
      setOpen(false)
    }
  }

  return (
    <div className="relative">
      <Input
        value={value}
        onChange={(event) => {
          justPicked.current = false
          setActiveIndex(0)
          setOpen(true)
          onChange(event.target.value)
        }}
        onFocus={() => {
          if (!justPicked.current) setOpen(true)
        }}
        onBlur={() => setOpen(false)}
        onKeyDown={handleKeyDown}
        placeholder={placeholder}
        aria-label={ariaLabel}
        role="combobox"
        aria-expanded={listOpen}
        aria-controls={listOpen ? listId : undefined}
        aria-autocomplete="list"
        autoComplete="off"
      />
      {listOpen && (
        <ul
          id={listId}
          role="listbox"
          className="absolute inset-x-0 top-full z-50 mt-1 max-h-56 overflow-y-auto rounded-md border bg-popover p-1 shadow-md"
        >
          {matches.map((match, index) => (
            <li key={match.id}>
              <button
                type="button"
                role="option"
                aria-selected={index === activeIndex}
                // Keeps the field focused (and the phone keyboard up) so the
                // tap lands on the option instead of being eaten by the blur.
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => pick(match.name)}
                className={cn(
                  "flex min-h-11 w-full flex-col justify-center rounded-sm px-2 py-1.5 text-left text-sm",
                  index === activeIndex && "bg-accent text-accent-foreground",
                )}
              >
                <span>{match.name}</span>
                {match.matchedAlias && (
                  <span className="text-xs text-muted-foreground">
                    {match.matchedAlias}
                  </span>
                )}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
