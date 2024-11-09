import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progressBar", "timer"]
  static values = {
    createdAt: String,
    startedAt: String,
    duration: Number,
    interval: Number
  }

  connect() {
    this.createdTime = new Date(this.createdAtValue)
    //check if startedAtValue is null
    this.startTime = this.startedAtValue ? new Date(this.startedAtValue) : undefined
    this.updateProgress()
    this.updateInterval = setInterval(() => this.updateProgress(), 100)
  }

  disconnect() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
    }
  }

  updateProgress() {
    const now = new Date()
    if (this.startTime === undefined) {
      const totalInterval = this.intervalValue * 1000
      const elapsed = now - this.createdTime
      const remaining = Math.max(0, totalInterval - elapsed)
      this.setProgress(remaining, totalInterval)

      // Update timer text
      const secondsRemaining = Math.ceil(remaining / 1000)
      this.timerTarget.textContent = `Next round in ${secondsRemaining} seconds`
    } else {
      const totalDuration = this.durationValue * 1000
      const elapsed = now - this.startTime
      const remaining = Math.max(0, totalDuration - elapsed)
      this.setProgress(remaining, totalDuration)

      // Update timer text
      const secondsRemaining = Math.ceil(remaining / 1000)
      this.timerTarget.textContent = `${secondsRemaining}s remaining`

      // If time is up, clear the interval
      if (remaining <= 0) {
        this.timerTarget.textContent = "Time's up!"
        this.progressBarTarget.parentElement.classList.add('hidden')
        clearInterval(this.updateInterval)
      }
    }
  }

  setProgress(remaining, totalDuration) {
    const percentageRemaining = Math.max(0, Math.min(100, (remaining / totalDuration) * 100))
    this.progressBarTarget.style.width = `${percentageRemaining}%`
  }
}
