import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  fly() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    const image = this.closestImage()
    const cartLink = document.getElementById("cart-link")
    if (!image || !cartLink) return

    const imageRect = image.getBoundingClientRect()
    const cartRect = cartLink.getBoundingClientRect()
    const clone = image.cloneNode(true)

    clone.classList.add("cart-fly-image")
    clone.style.left = `${imageRect.left}px`
    clone.style.top = `${imageRect.top}px`
    clone.style.width = `${imageRect.width}px`
    clone.style.height = `${imageRect.height}px`

    document.body.appendChild(clone)

    requestAnimationFrame(() => {
      clone.style.transform = `translate(${cartRect.left - imageRect.left + (cartRect.width / 2) - (imageRect.width / 2)}px, ${cartRect.top - imageRect.top - 12}px) scale(0.18)`
      clone.style.opacity = "0"
    })

    setTimeout(() => clone.remove(), 720)
  }

  closestImage() {
    return this.element.closest(".product-card, .product-detail")?.querySelector("img")
  }
}
