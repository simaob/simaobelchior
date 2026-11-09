import { Controller } from "@hotwired/stimulus"

const DRAG_DISTANCE = 4

// Connects to data-controller="image-zoom" on article bodies (layouts/action_text/contents/_content).
// Opens the larger copy behind an image link over the page. A click on the image switches between
// fitting the screen and full size, where it can be scrolled or dragged around.
// Escape, the close button or a click beside the image closes it.
export default class extends Controller {
  connect() {
    this.close = this.close.bind(this)
    this.update = this.update.bind(this)
    // Close before Turbo caches the page, so Back doesn't bring the viewer back open
    document.addEventListener("turbo:before-cache", this.close)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.close)
    this.close()
  }

  // Listens for clicks on the whole body, since the image links can't carry a data-action
  open(event) {
    const link = event.target.closest("a.attachment__zoom")
    if (!link) return
    // Modified clicks still open the image in a new tab or window
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()

    const preview = link.querySelector("img")
    const dialog = this.buildDialog()
    const image = dialog.querySelector("img")
    image.alt = preview?.alt || ""
    const full = image.cloneNode()

    // Show the copy already on the page, stretched to the screen, until the larger one has loaded
    image.src = preview?.currentSrc || link.href
    full.src = link.href
    full.decode()
      .then(() => image.replaceWith(full))
      .catch(() => {}) // keep the smaller copy
      .finally(() => {
        dialog.classList.remove("is-loading")
        if (dialog === this.dialog) this.update()
      })

    this.dialog = dialog
    document.body.append(dialog)
    dialog.showModal()
    window.addEventListener("resize", this.update)
  }

  close() {
    this.dialog?.close()
  }

  // The image can be zoomed when it is shown smaller than its full size
  update() {
    const dialog = this.dialog
    if (!dialog || dialog.classList.contains("is-loading")) return

    const image = dialog.querySelector("img")
    const zoomed = dialog.classList.contains("is-zoomed")
    dialog.classList.toggle("is-zoomable", zoomed || image.naturalWidth > image.clientWidth)
  }

  zoom(event) {
    const dialog = this.dialog
    if (!dialog.classList.contains("is-zoomable")) return this.close()

    // Keep the point that was clicked under the pointer
    const image = event.target
    const box = image.getBoundingClientRect()
    const x = (event.clientX - box.left) / box.width
    const y = (event.clientY - box.top) / box.height
    if (dialog.classList.toggle("is-zoomed")) {
      dialog.scrollLeft = x * image.clientWidth - event.clientX
      dialog.scrollTop = y * image.clientHeight - event.clientY
    }
    this.update()
  }

  // Touch screens scroll a zoomed image natively. A mouse drags it.
  drag(event) {
    const dialog = this.dialog
    if (event.pointerType !== "mouse" || event.button !== 0) return
    if (!dialog.classList.contains("is-zoomed") || !event.target.matches(".image-zoom__image")) return
    event.preventDefault()

    const image = event.target
    const start = { x: event.clientX, y: event.clientY, left: dialog.scrollLeft, top: dialog.scrollTop }
    const move = (moveEvent) => {
      const dx = moveEvent.clientX - start.x
      const dy = moveEvent.clientY - start.y
      if (Math.hypot(dx, dy) > DRAG_DISTANCE) {
        this.dragged = true
        dialog.classList.add("is-dragging")
      }
      dialog.scrollLeft = start.left - dx
      dialog.scrollTop = start.top - dy
    }

    this.dragged = false
    image.setPointerCapture(event.pointerId)
    image.addEventListener("pointermove", move)
    image.addEventListener("lostpointercapture", () => {
      image.removeEventListener("pointermove", move)
      dialog.classList.remove("is-dragging")
    }, { once: true })
  }

  buildDialog() {
    const dialog = document.createElement("dialog")
    dialog.className = "image-zoom is-loading"
    dialog.setAttribute("aria-label", "Enlarged image")
    dialog.innerHTML = `
      <button type="button" class="image-zoom__close" aria-label="Close">
        <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>
      </button>
      <img class="image-zoom__image" alt="" draggable="false">`

    dialog.addEventListener("pointerdown", (event) => this.drag(event))
    dialog.addEventListener("click", (event) => {
      if (this.dragged) {
        this.dragged = false
      } else if (event.target.matches(".image-zoom__image")) {
        this.zoom(event)
      } else {
        this.close()
      }
    })
    dialog.addEventListener("close", () => {
      window.removeEventListener("resize", this.update)
      dialog.remove()
      if (dialog === this.dialog) this.dialog = null
    })
    return dialog
  }
}
