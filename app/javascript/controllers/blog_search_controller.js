import { Controller } from "@hotwired/stimulus"

// The search box that was cleared, kept until the next page has loaded
let clearedInput = null

// Connects to data-controller="blog-search" on the blog's search form.
// Clearing the box, by deleting the text, its clear button or Escape, searches for nothing,
// which shows all articles again.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    // Turbo can show a cached copy of the page first, before the real one arrives
    if (!clearedInput || document.documentElement.hasAttribute("data-turbo-preview")) return

    // Keeps the cursor in the box, with anything typed while the page loaded
    this.inputTarget.value = clearedInput.value
    this.inputTarget.focus()
    clearedInput = null
  }

  submitIfCleared() {
    const input = this.inputTarget
    // Only on a page of results, as the page without a search already shows everything
    if (input.value !== "" || input.defaultValue === "") return

    clearedInput = input
    this.element.requestSubmit()
  }
}
