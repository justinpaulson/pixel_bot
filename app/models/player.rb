class Player < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :user
  belongs_to :game
  has_many :scores, through: :user

  after_create_commit -> { broadcast_player_update }

  def total_points_for_game
    scores.where(round_id: game.rounds.pluck(:id)).sum(:points)
  end

  private

  def broadcast_player_update
    broadcast_replace_to [ game, "players" ],
      target: "players",
      partial: "games/players",
      locals: { game: game }

    if game.players.count > 2
      broadcast_replace_to [ game, "players" ],
        target: "start",
        html: "<div class='mt-4'>
  <a href=#{start_game_path(game)} class='rounded bg-blue-600 text-white p-2 hover:bg-blue-700'>Start Game</a>
</div>"
    end
  end
end
