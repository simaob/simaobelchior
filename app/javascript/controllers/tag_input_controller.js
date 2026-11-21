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
    this.token = this.currentToken()
    const query = normalize(this.token.text)
    this.matches = query ? this.search(query) : []
    this.highlighted = this.matches.length ? 0 : -1
    this.render()
    this.refresh()
  }

  navigate(event) {
    // Keys typed while composing a character with an input method are for the input method
    if (event.isComposing || !this.matches.length) return

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

  // The suggestions were for the tag the caret was in, so they go when it moves to another
  moveCaret() {
    if (this.matches.length && this.currentToken().start !== this.token.start) this.close()
  }

  leave() {
    this.close()
  }

  // Clicking a suggestion leaves the focus in the field
  holdFocus(event) {
    event.preventDefault()
  }

  // Tag names are read from data attributes rather than Stimulus action params, which would
  // turn a tag like "1.0" into a number
  pick({ currentTarget }) {
    this.accept(currentTarget.dataset.name)
  }

  // A most used tag's button
  toggle({ currentTarget }) {
    const name = currentTarget.dataset.name
    const names = this.names
    this.names = names.includes(name) ? names.filter(other => other !== name) : [...names, name]
  }

  // The "did you mean" button on a warning
  replace({ currentTarget: { dataset: { from, to } } }) {
    this.names = this.names.map(name => name === from ? to : name)
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
  // an existing one. A tag that's the start of an existing one is left alone while the caret
  // is in it, as it's most likely still being typed.
  refresh() {
    const names = this.names
    const inField = new Set(names)

    for (const chip of this.chipTargets) {
      const active = inField.has(chip.dataset.name)
      chip.classList.toggle("active", active)
      chip.setAttribute("aria-pressed", active)
    }

    const current = normalize(this.currentToken().text)
    const known = new Set(this.tagsValue.map(tag => tag.name))
    const typing = name => name === current && this.tagsValue.some(tag => tag.name.startsWith(name))
    const warnings = names
      .filter(name => !known.has(name) && !typing(name))
      .map(name => [ name, this.lookalike(name) ])
      .filter(([, tag]) => tag)

    // Rebuilding them when nothing changed would swallow a click on one of their buttons
    const key = JSON.stringify(warnings.map(([ name, tag ]) => [ name, tag.name ]))
    if (key === this.warningsKey) return
    this.warningsKey = key

    this.warningsTarget.replaceChildren(...warnings.map(([ name, tag ]) => warning(name, tag)))
    this.warningsTarget.hidden = warnings.length === 0
  }

  // The most used existing tag that a new tag could be a variant of
  lookalike(name) {
    return this.tagsValue.find(tag => similar(tag.name, name))
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

// Letters and digits, plus the + and # that tell c++ and c# apart
function letters(name) {
  return name.toLowerCase().replace(/[^\p{L}\p{N}+#]/gu, "")
}

// Without a plural "s" too, so "action text", "action-text" and "actiontext" all come out
// the same
function squash(name) {
  const squashed = letters(name)
  return squashed.length > 3 ? squashed.replace(/s$/, "") : squashed
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

// Spelt differently, or with a typo or two. Short names only match when they're the same
// once squashed, as one letter apart is often a different word (tdd and bdd, node and code).
// The same test as Tag.similar?, which the tags:lookalikes task uses, so keep the two in step.
function similar(a, b) {
  if (squash(a) === squash(b)) return true

  const [ x, y ] = [ letters(a), letters(b) ]
  const longest = Math.max(x.length, y.length)
  const allowed = longest >= 8 ? 2 : longest >= 5 ? 1 : 0
  return allowed > 0 && distance(x, y) <= allowed
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
  option.dataset.action = "tag-input#pick"
  option.dataset.name = tag.name

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
  button.dataset.from = name
  button.dataset.to = tag.name
  button.textContent = tag.name

  line.append(`“${name}” would be a new tag. Did you mean `, button, "?")
  return line
}
