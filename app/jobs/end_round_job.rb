class EndRoundJob < ApplicationJob
  queue_as :default

  def perform(round_id)
    round = Round.find(round_id)
    puts "Found the round with id: #{round_id}"
    return unless round

    game = round.game

    if game.rounds.count < game.players.count
      puts "We are creating a new round!!"
      new_round = Round.create!(game: game)
    else
      puts "Game is over, we are completing the game!!"
      game.update!(completed_at: Time.current)
    end
  end
end
