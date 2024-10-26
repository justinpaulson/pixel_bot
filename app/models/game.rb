class Game < ApplicationRecord
  before_create :set_uuid

  has_many :players, dependent: :destroy
  has_many :rounds, dependent: :destroy

  belongs_to :created_by, class_name: "User"

  after_update_commit -> { broadcast_game_over if completed? }

  def current_round
    rounds.last || false
  end

  def completed?
    completed_at.present?
  end

  private

  def set_uuid
    self.id = SecureRandom.uuid if id.blank?
  end

  def broadcast_game_over
    self.players.each do |player|
      broadcast_replace_to [ self, player.user, "round" ],
        target: "round",
        partial: "games/game_over",
        locals: { game: self }
    end
  end
end
