class Score < ApplicationRecord
  belongs_to :round
  belongs_to :user

  after_commit do
    broadcast_replace_to [ round.game, "players" ],
      target: "players",
      partial: "rounds/player_list",
      locals: { game: round.game, round: round }
  end
end
