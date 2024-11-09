import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "slide", "previousButton", "nextButton", "indicator"]
  static values = { index: Number }

  connect() {
    if (this.slideTargets.length > 0) {
      this.updateSlidePosition()
      this.updateButtons()
      this.updateIndicators()
    }

    // Setup observer for new slides
    this.observer = new MutationObserver(this.handleNewSlide.bind(this))
    this.observer.observe(this.containerTarget, { childList: true })
  }

  disconnect() {
    this.observer.disconnect()
  }

  handleNewSlide(mutations) {
    mutations.forEach(mutation => {
      if (mutation.addedNodes.length > 0) {
        this.indexValue = 0
        this.updateSlidePosition()
        this.updateButtons()
        this.updateIndicators()
      }
    })
  }

  next() {
    this.indexValue++
    this.updateSlidePosition()
    this.updateButtons()
    this.updateIndicators()
  }

  previous() {
    this.indexValue--
    this.updateSlidePosition()
    this.updateButtons()
    this.updateIndicators()
  }

  goToSlide(event) {
    this.indexValue = parseInt(event.currentTarget.dataset.index)
    this.updateSlidePosition()
    this.updateButtons()
    this.updateIndicators()
  }

  updateSlidePosition() {
    const offset = this.indexValue * -100
    this.containerTarget.style.transform = `translateX(${offset}%)`
  }

  updateButtons() {
    if (this.hasPreviousButtonTarget && this.hasNextButtonTarget) {
      this.previousButtonTarget.disabled = this.indexValue === 0
      this.nextButtonTarget.disabled = this.indexValue === this.slideTargets.length - 1
    }
  }

  updateIndicators() {
    if (this.hasIndicatorTarget) {
      this.indicatorTargets.forEach((indicator, index) => {
        indicator.classList.toggle("bg-white", index === this.indexValue)
        indicator.classList.toggle("bg-white/60", index !== this.indexValue)
      })
    }
  }
}
