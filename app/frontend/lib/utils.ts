import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// The client-side twin of Ruby's `Normalizable.normalize_key` — accent-stripped,
// lowercased, trimmed, whitespace-collapsed. Every client-side name match runs
// through this so a query can never fold differently from the **Normalized keys**
// the server computes for the Exercise catalog and for weight history.
export function normalizeForSearch(value: string): string {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ")
}
