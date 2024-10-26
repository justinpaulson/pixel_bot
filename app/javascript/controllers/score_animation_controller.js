// app/javascript/controllers/score_animation_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    current: Number,
    total: Number,
    position: Number
  }

  connect() {
    this.previousCurrent = this.currentValue
    this.previousTotal = this.totalValue
    this.previousPosition = this.positionValue
  }

  currentValueChanged() {
    if (this.previousCurrent !== undefined && this.currentValue > this.previousCurrent) {
      this.animateScore()
    }
    this.previousCurrent = this.currentValue
  }

  totalValueChanged() {
    if (this.previousTotal !== undefined && this.totalValue > this.previousTotal) {
      this.animateScore()
    }
    this.previousTotal = this.totalValue
  }

  positionValueChanged() {
    if (this.previousPosition !== undefined && this.positionValue < this.previousPosition) {
      this.animatePosition()
    }
    this.previousPosition = this.positionValue
  }

  animateScore() {
    this.element.classList.add('scale-105', 'bg-green-100')
    setTimeout(() => {
      this.element.classList.remove('scale-105', 'bg-green-100')
    }, 500)
  }

  animatePosition() {
    this.element.classList.add('bg-yellow-50')
    setTimeout(() => {
      this.element.classList.remove('bg-yellow-50')
    }, 500)
  }
}
