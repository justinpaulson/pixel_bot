class Game < ApplicationRecord
  ROUNDS_AHEAD = 2
  attribute :drawing_model, :string, default: -> { DrawingModels.default }
  attr_readonly :drawing_model
  before_create -> { self.id ||= SecureRandom.uuid }
  has_many :players, dependent: :destroy
  has_many :rounds, -> { order(:number) }, dependent: :destroy
  belongs_to :created_by, class_name: "User"

  validates :mode, inclusion: { in: %w[solo party] }
  validates :category, inclusion: { in: PromptCatalog::CATEGORIES.keys }
  validates :round_limit, inclusion: { in: [ 3, 5, 10 ] }
  validates :drawing_model, inclusion: { in: DrawingModels::OPTIONS.keys }

  def artist
    DrawingModels::OPTIONS.fetch(drawing_model)
  end

  def current_round
    rounds.find_by(number: active_round_number)
  end

  def completed?
    completed_at.present?
  end

  def start!
    with_lock do
      return false if started_at? || edition != 2
      update!(started_at: Time.current)
      prepare_rounds!
    end
    true
  end

  def advance!(round_id, automatic: false)
    activated = nil
    with_lock do
      round = current_round
      return false unless round && round.id == round_id.to_i && round.status == "revealed" && !completed?
      return false if automatic && (!round.next_round_at || Time.current < round.next_round_at)
      update!(active_round_number: active_round_number + 1)
      prepare_rounds!
      next_round = current_round
      if next_round.status == "ready"
        next_round.activate!
        activated = next_round
      end
    end
    if activated
      EndRoundJob.set(wait_until: activated.deadline).perform_later(activated.id)
    end
    true
  end

  def prepare_ahead!
    with_lock do
      return if !started_at? || completed? || edition != 2
      prepare_rounds!
    end
  end

  def join!(user)
    with_lock do
      return players.find_by(user: user) if players.exists?(user: user)
      return nil if edition != 2 || completed? || (mode == "solo" && user != created_by) || players.count >= 12
      players.create!(user: user, last_seen_at: Time.current)
    end
  end

  private

  # Called under the game lock. Pick answers once, without repeats, and enqueue
  # the whole window on commit so all three drawings can run concurrently.
  def prepare_rounds!
    last_number = [ active_round_number + ROUNDS_AHEAD, round_limit ].min
    (active_round_number..last_number).each do |number|
      next if rounds.exists?(number: number)
      entry = PromptCatalog.pick(category: category, excluding: rounds.pluck(:word))
      rounds.create!(entry.merge(user: created_by, number: number))
    end
  end
end
