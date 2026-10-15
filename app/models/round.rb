class Round < ApplicationRecord
  DURATION = 90.seconds
  GENERATION_TIMEOUT = 3.minutes
  has_many :messages, dependent: :destroy
  has_many :scores, dependent: :destroy
  belongs_to :game
  belongs_to :user

  validates :status, inclusion: { in: %w[pending generating ready playing revealed failed] }
  after_create_commit -> { GenerateDrawingJob.perform_later(id) if game.edition == 2 }

  def activate!
    update!(status: "playing", started_at: Time.current)
  end

  def running?
    status == "playing" && started_at.present? && Time.current < deadline
  end

  def deadline
    started_at && started_at + DURATION
  end

  def refresh!
    expired = status == "playing" && Time.current >= deadline
    stalled = %w[pending generating].include?(status) && (generation_started_at || created_at) < GENERATION_TIMEOUT.ago
    return unless expired || stalled

    game.with_lock do
      reload
      if status == "playing" && Time.current >= deadline
        reveal!
      elsif %w[pending generating].include?(status) && (generation_started_at || created_at) < GENERATION_TIMEOUT.ago
        update!(status: "failed", generation_token: nil, error_message: "Pixel took too long to finish this drawing. Please try again.")
      end
    end
  end

  def guess!(user, answer)
    game.with_lock do
      reload
      return { message: "Join this game first.", accepted: false } unless game.players.exists?(user: user)
      reveal! if status == "playing" && Time.current >= deadline
      return { message: "This round is no longer taking guesses.", accepted: false } unless running?
      return { message: "You already got it! Let the others guess.", accepted: true } if scores.exists?(user: user)
      return { message: "Not quite. Take another look!", accepted: false } unless AnswerMatcher.match?(answer, [ word, *aliases ])

      points = [ 100, (1000 - (Time.current - started_at) * 10).round ].max
      scores.create!(user: user, points: points)
      reveal! if scores.count >= game.players.count
      { message: "You got it! +#{points} points", accepted: true, points: points }
    end
  end

  # Call under the game lock so scoring, timeouts and host actions cannot race.
  def reveal!
    return unless status == "playing"
    update!(status: "revealed", ended_at: Time.current)
    game.update!(completed_at: Time.current) if number >= game.round_limit
  end

  def skip!
    game.with_lock do
      reload
      reveal!
    end
  end

  def retry_drawing!
    game.with_lock do
      reload
      return false unless status == "failed"
      update!(status: "pending", generation_started_at: Time.current, generation_token: nil, error_message: nil)
    end
    GenerateDrawingJob.perform_later(id)
    true
  end
end
