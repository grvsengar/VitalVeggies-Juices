import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.enabled = window.matchMedia("(pointer: fine)").matches && !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.frame = null
    this.pendingState = null
  }

  disconnect() {
    if (this.frame) cancelAnimationFrame(this.frame)
  }

  move(event) {
    if (!this.enabled) return

    const bounds = this.element.getBoundingClientRect()
    const horizontal = (event.clientX - bounds.left) / bounds.width
    const vertical = (event.clientY - bounds.top) / bounds.height

    this.pendingState = {
      rotateY: (horizontal - 0.5) * 10,
      rotateX: (0.5 - vertical) * 8,
      glowX: horizontal * 100,
      glowY: vertical * 100
    }

    if (this.frame) return

    this.frame = requestAnimationFrame(() => {
      if (!this.pendingState) return

      this.element.style.setProperty("--tilt-rotate-x", `${this.pendingState.rotateX}deg`)
      this.element.style.setProperty("--tilt-rotate-y", `${this.pendingState.rotateY}deg`)
      this.element.style.setProperty("--tilt-glow-x", `${this.pendingState.glowX}%`)
      this.element.style.setProperty("--tilt-glow-y", `${this.pendingState.glowY}%`)
      this.pendingState = null
      this.frame = null
    })
  }

  reset() {
    if (!this.enabled) return

    if (this.frame) {
      cancelAnimationFrame(this.frame)
      this.frame = null
    }

    this.pendingState = null
    this.element.style.setProperty("--tilt-rotate-x", "0deg")
    this.element.style.setProperty("--tilt-rotate-y", "0deg")
    this.element.style.setProperty("--tilt-glow-x", "50%")
    this.element.style.setProperty("--tilt-glow-y", "35%")
  }
}
