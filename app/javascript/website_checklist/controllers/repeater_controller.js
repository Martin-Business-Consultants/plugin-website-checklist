import { Controller } from "@hotwired/stimulus"

// The plugin's own repeater (website-checklist--repeater): a list of rows a person adds to and takes from inside a
// form (the webhooks, and each one's keys and values). Add copies the template, its placeholder swapped for a fresh index; Remove takes a new
// row away, and hides a saved one and sets its _destroy so the save deletes it. Repeaters nest:
// give each its own placeholder. Rows carry data-repeater-row.
export default class extends Controller {
  static targets = [ "list", "template" ]
  static values = { placeholder: { type: String, default: "NEW_ROW" } }

  #added = 0

  add(event) {
    event.preventDefault()
    const index = `${Date.now()}${this.#added++}`
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replaceAll(this.placeholderValue, index))
    this.listTarget.lastElementChild?.querySelector("input:not([type=hidden]), textarea, select")?.focus()
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-repeater-row]")
    const destroy = row?.querySelector(":scope input[name$='[_destroy]']")

    if (destroy) {
      destroy.value = "1"
      row.hidden = true
    } else {
      row?.remove()
    }
  }
}
