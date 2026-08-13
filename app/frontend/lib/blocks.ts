// The canonical shape of a Workout's `blocks` JSONB as it crosses the Inertia
// boundary. Every surface that renders or edits blocks imports from here — the
// blocks renderer, the inline workout editor, the trainer live board and the
// student live session screen — so casing drift between the Rails props and the
// React components cannot silently break rendering again.
//
// Keys are camelCase because the caseshift Vite plugin converts the snake_case
// Rails props on the way in (and back on the way out).

// Resolved live at read time by BlockMedia (server side), so it is present only
// on surfaces whose serializer asks for it.
export type ExerciseMediaItem = {
  id: string
  thumbUrl: string
  fullUrl: string
  isVideo: boolean
}

export type ExerciseBlock = {
  kind: "exercise"
  name: string
  prescription: string
  restS?: number
  notes?: string
  // Decorated by the live-session serializers with the student's last recorded
  // load for this movement; absent everywhere else.
  weight?: string | null
  media?: ExerciseMediaItem[]
}

export type GroupItem = {
  name: string
  prescription: string
  notes?: string
  weight?: string | null
  media?: ExerciseMediaItem[]
}

export type GroupBlock = {
  kind: "group"
  label?: string
  rounds?: number
  items: GroupItem[]
}

export type FreeformBlock = {
  kind: "freeform"
  textMd: string
}

export type Block = ExerciseBlock | GroupBlock | FreeformBlock
