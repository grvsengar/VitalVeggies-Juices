import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "item"]

  connect() {
    this.selectedIndex = -1
  }

  toggle(event) {
    event.preventDefault()
    this.element.hidden = !this.element.hidden

    if (!this.element.hidden) {
      this.inputTarget.focus()
      this.inputTarget.value = ""
      this.selectedIndex = -1
      this.submitSearch()
    }
  }

  close() {
    this.element.hidden = true
    this.selectedIndex = -1
  }

  search() {
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => this.submitSearch(), 120)
  }

  navigate(event) {
    const items = this.itemTargets
    if (items.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.selectedIndex = (this.selectedIndex + 1) % items.length
      this.updateSelection()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.selectedIndex = (this.selectedIndex - 1 + items.length) % items.length
      this.updateSelection()
    } else if (event.key === "Enter") {
      if (this.selectedIndex >= 0) {
        event.preventDefault()
        items[this.selectedIndex].click()
        this.close()
      } else if (items.length === 1) {
        event.preventDefault()
        items[0].click()
        this.close()
      }
    }
  }

  disconnect() {
    clearTimeout(this.searchTimeout)
  }

  submitSearch() {
    this.inputTarget.form?.requestSubmit()
    this.selectedIndex = -1
  }

  updateSelection() {
    this.itemTargets.forEach((item, index) => {
      item.classList.toggle("command-palette__result-item--selected", index === this.selectedIndex)
      if (index === this.selectedIndex) {
        item.scrollIntoView({ block: "nearest" })
      }
    })
  }
}
