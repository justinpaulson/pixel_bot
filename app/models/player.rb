class Player < ApplicationRecord
  belongs_to :user
  belongs_to :game
  has_many :scores, through: :user

  after_create_commit -> { broadcast_player_update }

  def total_points_for_game
    scores.where(round_id: game.rounds.pluck(:id)).sum(:points)
  end

  private

  def broadcast_player_update
    broadcast_replace_to [game, "players"],
      target: "players",
      partial: "games/players",
      locals: { game: game }
  end
end
