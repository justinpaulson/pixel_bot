require "test_helper"

class RoundTest < ActiveSupport::TestCase
  test "correct solo guess earns points once and reveals the answer" do
    game = build_game
    round = ready_round(game)
    travel 10.seconds do
      result = round.guess!(users(:one), "jurassic  park!")
      assert result[:accepted]
      assert_in_delta 900, result[:points], 1
      assert_equal "revealed", round.reload.status
      assert_no_difference "Score.count" do
        round.guess!(users(:one), "Jurassic Park")
      end
    end
  end

  test "all party players including the host can score without revealing to other guessers" do
    game = build_game(mode: "party", players: [ users(:one), users(:two) ])
    round = ready_round(game)
    assert round.guess!(users(:one), "Jurassic Park")[:accepted]
    assert_equal "playing", round.reload.status
    state = GameState.new(game, users(:two)).as_json
    assert_nil state[:round][:answer]
    assert_not state.to_json.include?("Jurassic Park")
    assert_not state.to_json.include?("one@example.com")
    assert_not round.guess!(users(:two), "Titanic")[:accepted]
    assert round.guess!(users(:two), "Jurassic Park")[:accepted]
    assert_equal "revealed", round.reload.status
    assert_equal "Jurassic Park", GameState.new(game, users(:two)).as_json[:round][:answer]
    assert_equal 2, round.scores.count
  end

  test "outsiders and guesses after the deadline cannot score" do
    game = build_game
    round = ready_round(game)
    assert_not round.guess!(users(:two), round.word)[:accepted]
    travel 90.seconds do
      assert_not round.guess!(users(:one), round.word)[:accepted]
      assert_equal "revealed", round.reload.status
      assert_empty round.scores
    end
  end

  test "final reveal completes the game and timers are idempotent" do
    game = build_game
    round = ready_round(game, number: 3)
    game.update!(active_round_number: 3)
    travel 91.seconds do
      2.times { EndRoundJob.perform_now(round.id) }
      assert game.reload.completed?
      assert_equal "complete", GameState.new(game, users(:one)).as_json[:phase]
      assert_equal 1, game.rounds.count
      assert_empty round.scores
    end
  end

  test "stalled generation can be retried without starting the guess clock" do
    game = build_game
    game.start!
    round = game.current_round
    travel 181.seconds do
      round.refresh!
      assert_equal "failed", round.status
      assert_nil round.started_at
      assert round.retry_drawing!
      assert_equal "pending", round.reload.status
      assert_not round.retry_drawing!
    end
  end

  test "hints appear after thirty five seconds and future art is omitted from state" do
    game = build_game
    round = ready_round(game)
    ready_round(game, number: 2, status: "ready", word: "Future Secret")
    state = GameState.new(game, users(:one)).as_json
    assert_nil state[:round][:hint]
    assert_not state.to_json.include?("Future Secret")
    travel 36.seconds do
      assert_equal round.hint, GameState.new(game, users(:one)).as_json[:round][:hint]
    end
  end
end
