require "test_helper"

class GameTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "artist is restricted to the supported models and stays fixed for the room" do
    game = build_game(drawing_model: "gpt-6-luna")
    assert_equal "Luna", game.artist[:name]
    assert_raises(ActiveRecord::ReadonlyAttributeError) { game.update!(drawing_model: "gpt-6-astra") }
    assert_equal "gpt-6-luna", game.reload.drawing_model
    assert_raises(ActiveRecord::RecordInvalid) { build_game(drawing_model: "unsupported-model") }
  end

  test "solo starts once and the host can guess without a drawer" do
    game = build_game
    assert_difference "Round.count", 3 do
      assert game.start!
      assert_not game.start!
    end
    assert_equal "pending", game.current_round.status
    assert_equal [ 1, 2, 3 ], game.rounds.pluck(:number)
    assert_equal 3, game.rounds.pluck(:word).uniq.size
    assert_equal 1, game.players.count
  end

  test "prepares two rounds ahead immediately and refills even when the next drawing is pending" do
    game = build_game(rounds: 5)
    assert_enqueued_jobs 3, only: PrepareDrawingJob do
      game.start!
    end
    assert_no_difference "Round.count" do
      2.times { game.prepare_ahead! }
    end
    first = game.current_round
    first.update!(status: "revealed")
    assert game.advance!(first.id)
    assert_equal "pending", game.current_round.status
    assert_equal [ 1, 2, 3, 4 ], game.rounds.pluck(:number)

    (2..4).each do |number|
      round = game.current_round
      assert_equal number, round.number
      round.update!(status: "revealed")
      assert game.advance!(round.id)
    end
    assert_equal 5, game.rounds.count
    assert_equal 5, game.rounds.pluck(:word).uniq.size
    game.update!(completed_at: Time.current)
    assert_no_enqueued_jobs do
      game.prepare_ahead!
    end
  end

  test "solo and completed rooms cannot admit new players" do
    game = build_game
    assert_nil game.join!(users(:two))
    assert_equal 1, game.players.count
    party = build_game(mode: "party")
    party.update!(completed_at: Time.current)
    assert_nil party.join!(users(:two))
  end

  test "membership is idempotent and capped at twelve" do
    game = build_game(mode: "party")
    assert_no_difference "Player.count" do
      2.times { game.join!(users(:one)) }
    end
    11.times do |i|
      game.join!(User.create!(email_address: "guest#{i}@example.com", password: "test-password"))
    end
    assert_nil game.join!(users(:two))
    assert_equal 12, game.players.count
  end

  test "advance is tied to the revealed round and activates prepared art only once" do
    game = build_game
    first = ready_round(game)
    second = ready_round(game, number: 2, status: "ready", word: "Titanic")
    assert_equal first, game.current_round
    assert_not game.advance!(first.id)
    first.skip!
    assert game.advance!(first.id)
    assert_not game.advance!(first.id)
    assert_equal second, game.current_round
    assert_equal "playing", second.reload.status
    assert second.started_at
    assert_equal 3, game.rounds.count
    assert_equal "pending", game.rounds.find_by(number: 3).status
  end

  test "catalog covers every category and avoids repeats" do
    assert_operator PromptCatalog.entries.count, :>=, 180
    PromptCatalog::DATA.keys.each do |category|
      pool = PromptCatalog.entries.select { |e| e[:category] == category }
      assert_operator pool.length, :>=, 20
      chosen = PromptCatalog.pick(category: category, excluding: pool.drop(1).pluck(:word))
      assert_equal pool.first[:word], chosen[:word]
    end
  end
end
