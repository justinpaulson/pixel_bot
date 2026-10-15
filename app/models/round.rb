class Round < ApplicationRecord
  DURATION = 15.seconds
  HINT_DELAY = 5.seconds
  GENERATION_TIMEOUT = 3.minutes
  has_many :messages, dependent: :destroy
  has_many :scores, dependent: :destroy
  belongs_to :game
  belongs_to :user

  validates :status, inclusion: { in: %w[pending generating ready playing revealed failed] }
  after_create_commit -> { PrepareDrawingJob.perform_later(id) if game.edition == 2 && status == "pending" }

  # Both cached art and provider results use the same guarded activation path.
  # A stale provider response must not replace a timeout or a newer attempt.
  def complete_drawing!(result, token: nil)
    activated = false
    accepted = game.with_lock do
      reload
      eligible = token ? status == "generating" && generation_token == token : status == "pending"
      next false unless eligible && !game.completed?
      update!(svg: result.fetch(:svg), model: result.fetch(:model),
        artwork_version: result.fetch(:artwork_version, DrawingBot::ARTWORK_VERSION), status: "ready",
        generation_seconds: token ? Time.current - generation_started_at : 0,
        generation_token: nil, error_message: nil)
      if game.active_round_number == number
        activate!
        activated = true
      end
      true
    end
    if activated
      EndRoundJob.set(wait_until: deadline).perform_later(id)
      game.prepare_ahead!
    end
    accepted
  end

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
        update!(status: "failed", generation_token: nil, error_message: "Drawing timed out. Try again.")
      end
    end
  end

  def guess!(user, answer)
    game.with_lock do
      reload
      return { message: "Join this game first.", accepted: false } unless game.players.exists?(user: user)
      reveal! if status == "playing" && Time.current >= deadline
      return { message: "Round over.", accepted: false } unless running?
      return { message: "Already correct!", accepted: true } if scores.exists?(user: user)
      return { message: "Not quite.", accepted: false } unless AnswerMatcher.match?(answer, [ word, *aliases ])

      points = [ 100, (1000 - (Time.current - started_at) * 10).round ].max
      scores.create!(user: user, points: points)
      reveal! if scores.count >= game.players.count
      { message: "Correct! +#{points}", accepted: true, points: points }
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
    PrepareDrawingJob.perform_later(id)
    true
  end
end
