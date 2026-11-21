import { Controller } from "@hotwired/stimulus"

const MAX_SUGGESTIONS = 8

// The comma-separated tags field on the article form. Suggests existing tags while typing,
// points out new tags that look like an existing one (a typo, a plural, "action text" for
// "action-text") and adds or removes the most used tags with a click.
export default class extends Controller {
  static targets = ["input", "suggestions", "warnings", "chip"]
  static values = { tags: Array }

  connect() {
    this.matches = []
    this.highlighted = -1
    this.refresh()
  }

  disconnect() {
    this.close()
  }

  // Typing in the field
  update() {
    const query = normalize(this.currentToken().text)
    this.matches = query ? this.search(query) : []
    this.highlighted = this.matches.length ? 0 : -1
    this.render()
    this.refresh()
  }

  navigate(event) {
    if (!this.matches.length) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.highlight(this.highlighted + 1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.highlight(this.highlighted - 1)
        break
      case "Enter":
        if (this.highlighted < 0) return
        event.preventDefault()
        this.accept(this.matches[this.highlighted].name)
        break
      case "Escape":
        event.preventDefault()
        this.close()
        break
    }
  }

  leave() {
    this.close()
    this.refresh()
  }

  // A suggestion is picked on mousedown, so the field keeps its focus
  pick({ params: { name } }) {
    this.accept(String(name))
  }

  // A most used tag's button
  toggle({ params }) {
    const name = String(params.name) // Stimulus reads a tag like "2024" as a number
    const names = this.names
    this.names = names.includes(name) ? names.filter(other => other !== name) : [...names, name]
  }

  // The "did you mean" button on a warning
  replace({ params: { from, to } }) {
    this.names = this.names.map(name => name === String(from) ? String(to) : name)
  }

  get names() {
    return this.inputTarget.value.split(",").map(normalize).filter(Boolean)
  }

  set names(names) {
    this.inputTarget.value = [...new Set(names)].join(", ")
    this.close()
    this.refresh()
  }

  // Replaces the tag under the caret with an existing one, ready for the next
  accept(name) {
    const { start, end } = this.currentToken()
    const value = this.inputTarget.value
    const before = value.slice(0, start).trimEnd()
    const after = value.slice(end).replace(/^,?\s*/, "")
    const head = `${before ? `${before} ` : ""}${name}, `

    this.inputTarget.value = head + after
    this.inputTarget.setSelectionRange(head.length, head.length)
    this.close()
    this.refresh()
  }

  // The text between the commas either side of the caret
  currentToken() {
    const value = this.inputTarget.value
    const caret = this.inputTarget.selectionStart ?? value.length
    const start = caret > 0 ? value.lastIndexOf(",", caret - 1) + 1 : 0
    const comma = value.indexOf(",", caret)
    const end = comma === -1 ? value.length : comma
    return { start, end, text: value.slice(start, end) }
  }

  // Existing tags that match what's typed, best match first. The tag typed so far is kept
  // when it exists already, so Enter can finish it. Tags already in the field are left out.
  search(query) {
    const taken = new Set(this.names)

    return this.tagsValue
      .filter(tag => tag.name === query || !taken.has(tag.name))
      .map(tag => ({ tag, score: score(tag.name, query) }))
      .filter(({ score }) => score > 0)
      .sort((a, b) => b.score - a.score || b.tag.count - a.tag.count || a.tag.name.localeCompare(b.tag.name))
      .slice(0, MAX_SUGGESTIONS)
      .map(({ tag }) => tag)
  }

  // Marks the most used tags already in the field and warns about new tags that look like
  // an existing one. The tag being typed is left alone until the caret moves on.
  refresh() {
    const names = this.names
    const inField = new Set(names)

    for (const chip of this.chipTargets) {
      const active = inField.has(chip.dataset.tagInputNameParam)
      chip.classList.toggle("active", active)
      chip.setAttribute("aria-pressed", active)
    }

    const typing = document.activeElement === this.inputTarget ? normalize(this.currentToken().text) : null
    const known = new Set(this.tagsValue.map(tag => tag.name))
    const warnings = names
      .filter(name => name !== typing && !known.has(name))
      .map(name => [ name, this.lookalike(name, inField) ])
      .filter(([, tag]) => tag)

    // Rebuilding them on blur would swallow a click on one of their buttons
    const key = JSON.stringify(warnings.map(([ name, tag ]) => [ name, tag.name ]))
    if (key === this.warningsKey) return
    this.warningsKey = key

    this.warningsTarget.replaceChildren(...warnings.map(([ name, tag ]) => warning(name, tag)))
    this.warningsTarget.hidden = warnings.length === 0
  }

  // The most used existing tag that a new tag could be a variant of
  lookalike(name, inField) {
    return this.tagsValue.find(tag => !inField.has(tag.name) && similar(tag.name, name))
  }

  render() {
    this.suggestionsTarget.replaceChildren(...this.matches.map((tag, index) => suggestion(tag, index)))
    this.suggestionsTarget.classList.toggle("show", this.matches.length > 0)
    this.inputTarget.setAttribute("aria-expanded", this.matches.length > 0)
    this.highlight(this.highlighted)
  }

  highlight(index) {
    const options = this.suggestionsTarget.querySelectorAll("[role=option]")
    if (!options.length) {
      this.inputTarget.removeAttribute("aria-activedescendant")
      return
    }

    this.highlighted = (index + options.length) % options.length
    options.forEach((option, i) => {
      const active = i === this.highlighted
      option.classList.toggle("active", active)
      option.setAttribute("aria-selected", active)
    })
    this.inputTarget.setAttribute("aria-activedescendant", options[this.highlighted].id)
  }

  close() {
    this.matches = []
    this.highlighted = -1
    this.render()
  }
}

// The same as Tag's normalizes, so names compare the way they're saved
function normalize(name) {
  return name.trim().toLowerCase()
}

// Letters and digits only, without a plural "s", so "action text", "action-text" and
// "actiontext" all come out the same
function squash(name) {
  const letters = name.toLowerCase().replace(/[^\p{L}\p{N}]/gu, "")
  return letters.length > 3 ? letters.replace(/s$/, "") : letters
}

function score(name, query) {
  if (name === query) return 100
  if (squash(name) === squash(query)) return 90
  if (name.startsWith(query)) return 80
  if (name.split(/[\s\-_.]+/).some(word => word.startsWith(query))) return 60
  if (name.includes(query)) return 40
  if (similar(name, query)) return 20
  return 0
}

// Spelt differently, or with a typo or two. The same test as Tag.similar?, which the
// tags:lookalikes task uses, so keep the two in step.
function similar(a, b) {
  const [ x, y ] = [ squash(a), squash(b) ]
  if (x === y) return true
  if (Math.min(x.length, y.length) < 3) return false
  return distance(x, y) <= (Math.max(x.length, y.length) >= 8 ? 2 : 1)
}

// Edits to turn one into the other, where swapping two neighbouring letters is one edit
function distance(a, b) {
  const d = Array.from({ length: a.length + 1 }, (_, i) => [ i, ...Array(b.length).fill(0) ])
  for (let j = 1; j <= b.length; j++) d[0][j] = j

  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1)
      }
    }
  }
  return d[a.length][b.length]
}

function suggestion(tag, index) {
  const item = document.createElement("li")
  item.setAttribute("role", "presentation")

  const option = document.createElement("button")
  option.type = "button"
  option.id = `tag-suggestion-${index}`
  option.tabIndex = -1
  option.className = "dropdown-item d-flex justify-content-between"
  option.setAttribute("role", "option")
  option.dataset.action = "mousedown->tag-input#pick:prevent"
  option.dataset.tagInputNameParam = tag.name

  const count = document.createElement("span")
  count.className = "opacity-75 ms-3"
  count.textContent = tag.count

  option.append(tag.name, count)
  item.append(option)
  return item
}

function warning(name, tag) {
  const line = document.createElement("div")

  const button = document.createElement("button")
  button.type = "button"
  button.className = "btn btn-link btn-sm p-0 border-0 align-baseline"
  button.dataset.action = "tag-input#replace"
  button.dataset.tagInputFromParam = name
  button.dataset.tagInputToParam = tag.name
  button.textContent = tag.name

  line.append(`“${name}” would be a new tag. Did you mean `, button, "?")
  return line
}
