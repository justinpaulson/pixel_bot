class Player < ApplicationRecord
  belongs_to :user
  belongs_to :game
  validates :user_id, uniqueness: { scope: :game_id }

  def total_points_for_game
    Score.joins(:round).where(user_id: user_id, rounds: { game_id: game_id }).sum(:points)
  end
end
