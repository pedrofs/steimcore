export const AVATAR_PALETTE = [
  "bg-rose-500",
  "bg-amber-500",
  "bg-emerald-500",
  "bg-sky-500",
  "bg-violet-500",
  "bg-fuchsia-500",
  "bg-cyan-500",
  "bg-indigo-500",
]

export function paletteColorFor(studentId: string) {
  const hex = studentId.replace(/-/g, "").slice(0, 8)
  const parsed = parseInt(hex, 16)
  const index = Number.isFinite(parsed) ? parsed % AVATAR_PALETTE.length : 0
  return AVATAR_PALETTE[index]
}

export function initials(name: string) {
  return name
    .split(/\s+/)
    .filter((s) => s.length > 0)
    .map((p) => p[0])
    .slice(0, 2)
    .join("")
    .toUpperCase()
}
