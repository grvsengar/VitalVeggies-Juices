import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel"]

  toggle() {
    const isOpen = this.panelTarget.classList.toggle("site-menu--open")
    this.buttonTarget.classList.toggle("site-menu-toggle--open", isOpen)
    this.buttonTarget.setAttribute("aria-expanded", isOpen.toString())
  }

  close() {
    this.panelTarget.classList.remove("site-menu--open")
    this.buttonTarget.classList.remove("site-menu-toggle--open")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  closeOnNavigation(event) {
    if (event.target.closest("a")) {
      this.close()
    }
  }
}
