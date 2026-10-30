import { Controller } from "@hotwired/stimulus"
import { highlightCode } from "lexxy"

// Connects to data-controller="syntax-highlight"
export default class extends Controller {
  connect() {
    highlightCode()
  }
}
