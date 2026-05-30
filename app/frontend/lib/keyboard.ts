/**
 * Track the soft-keyboard occlusion via the visualViewport API and expose it
 * as a `--keyboard-h` CSS variable on <html>, so any element can avoid being
 * hidden behind the keyboard (e.g. bottom sheets, fixed action bars). iOS
 * Safari does not shrink the layout viewport when the keyboard opens, so
 * `vh`/`bottom: 0` aren't enough on their own.
 */
let initialized = false

export function initKeyboardTracking() {
  if (initialized) return
  if (typeof window === "undefined") return
  const vp = window.visualViewport
  if (!vp) return
  initialized = true

  const update = () => {
    const occlusion = Math.max(
      0,
      window.innerHeight - vp.height - vp.offsetTop,
    )
    document.documentElement.style.setProperty(
      "--keyboard-h",
      `${Math.round(occlusion)}px`,
    )
  }

  vp.addEventListener("resize", update)
  vp.addEventListener("scroll", update)
  update()
}
