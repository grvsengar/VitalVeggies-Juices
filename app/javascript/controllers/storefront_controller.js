import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "vital-veggies-theme"

export default class extends Controller {
  static targets = ["themeButton"]

  connect() {
    this.applyTheme(this.preferredTheme())
  }

  toggleTheme() {
    const nextTheme = this.currentTheme() === "dark" ? "light" : "dark"
    localStorage.setItem(STORAGE_KEY, nextTheme)
    this.applyTheme(nextTheme)
  }

  preferredTheme() {
    const storedTheme = localStorage.getItem(STORAGE_KEY)
    if (storedTheme) return storedTheme

    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }

  currentTheme() {
    return document.documentElement.dataset.theme || "light"
  }

  applyTheme(theme) {
    document.documentElement.dataset.theme = theme

    this.themeButtonTargets.forEach((button) => {
      button.setAttribute("aria-pressed", String(theme === "dark"))

      const label = button.querySelector("[data-theme-label]")
      if (label) {
        label.textContent = theme === "dark" ? "Dark mode" : "Light mode"
      }
    })
  }
}
