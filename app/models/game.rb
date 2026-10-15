class Game < ApplicationRecord
  before_create -> { self.id ||= SecureRandom.uuid }
  has_many :players, dependent: :destroy
  has_many :rounds, -> { order(:number) }, dependent: :destroy
  belongs_to :created_by, class_name: "User"

  validates :mode, inclusion: { in: %w[solo party] }
  validates :category, inclusion: { in: PromptCatalog::CATEGORIES.keys }
  validates :round_limit, inclusion: { in: [ 3, 5, 10 ] }

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
      add_round!
    end
    true
  end

  def advance!(round_id)
    activated = nil
    with_lock do
      round = current_round
      return false unless round && round.id == round_id.to_i && round.status == "revealed" && !completed?
      update!(active_round_number: active_round_number + 1)
      next_round = current_round || add_round!
      if next_round.status == "ready"
        next_round.activate!
        activated = next_round
      end
    end
    if activated
      EndRoundJob.set(wait_until: activated.deadline).perform_later(activated.id)
      prepare_next!
    end
    true
  end

  def prepare_next!
    with_lock do
      return if completed? || active_round_number >= round_limit
      return unless %w[playing revealed].include?(current_round&.status)
      add_round! unless rounds.exists?(number: active_round_number + 1)
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

  def add_round!
    entry = PromptCatalog.pick(category: category, excluding: rounds.pluck(:word))
    rounds.create!(entry.merge(user: created_by, number: rounds.count + 1))
  end
end
