ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

class ActiveSupport::TestCase
  fixtures :users
  setup { freeze_time }

  def build_game(mode: "solo", players: [ users(:one) ], rounds: 3)
    game = Game.create!(created_by: players.first, mode: mode, category: "movies", round_limit: rounds, edition: 2)
    players.each { |user| game.join!(user) }
    game
  end

  def ready_round(game, number: 1, status: "playing", word: "Jurassic Park")
    game.update!(started_at: Time.current)
    game.rounds.create!(user: game.created_by, number: number, word: word, aliases: [], category: "movies", hint: "A prehistoric adventure", status: status,
      svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><circle cx="256" cy="256" r="100" fill="#315646"/></svg>',
      started_at: status == "playing" ? Time.current : nil)
  end
end
