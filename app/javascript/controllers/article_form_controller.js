import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="article-form"
export default class extends Controller {
  static targets = ["publishedAt"]

  saveAsDraft(event) {
    // Clear the published_at field when saving as draft
    this.publishedAtTarget.value = ""
  }
}
