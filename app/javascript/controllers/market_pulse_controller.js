import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message", "meta"]
  static values = { messages: Array }

  connect() {
    if (this.messagesValue.length === 0) return

    this.index = 0
    this.render()
    this.timer = setInterval(() => this.render(), 4200)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  render() {
    const entry = this.messagesValue[this.index % this.messagesValue.length]
    this.messageTarget.textContent = entry.message
    this.metaTarget.textContent = entry.meta
    this.element.classList.remove("market-pulse--animate")
    requestAnimationFrame(() => this.element.classList.add("market-pulse--animate"))
    this.index += 1
  }
}
