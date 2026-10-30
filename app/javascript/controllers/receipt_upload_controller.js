import { Controller } from "@hotwired/stimulus"

// Lightweight, local-only preview. Never parses receipt text or amounts.
// Server independently validates MIME, bytes and image dimensions.
export default class extends Controller {
  static targets = ["file", "filename", "preview", "selected", "zone", "submit"]

  connect() {
    this.previewUrl = null
  }

  disconnect() {
    if (this.previewUrl) URL.revokeObjectURL(this.previewUrl)
  }

  fileChanged() {
    const file = this.fileTarget.files?.[0]
    if (this.previewUrl) {
      URL.revokeObjectURL(this.previewUrl)
      this.previewUrl = null
    }
    if (!file) {
      this.selectedTarget.hidden = true
      this.previewTarget.hidden = true
      return
    }
    this.selectedTarget.hidden = false
    this.filenameTarget.textContent = `${file.name} · ${Math.ceil(file.size / 1024)} KB`
    if (file.type.startsWith("image/")) {
      this.previewUrl = URL.createObjectURL(file)
      this.previewTarget.src = this.previewUrl
      this.previewTarget.hidden = false
    } else {
      this.previewTarget.hidden = true
    }
  }

  dragEnter(event) {
    event.preventDefault()
    this.zoneTarget.classList.add("is-dragging")
  }

  dragOver(event) {
    event.preventDefault()
  }

  dragLeave(event) {
    if (!this.zoneTarget.contains(event.relatedTarget)) {
      this.zoneTarget.classList.remove("is-dragging")
    }
  }

  drop(event) {
    event.preventDefault()
    this.zoneTarget.classList.remove("is-dragging")
    if (!event.dataTransfer?.files?.length) return
    try {
      this.fileTarget.files = event.dataTransfer.files
      this.fileChanged()
    } catch (_) {
      this.fileTarget.focus()
    }
  }
}
