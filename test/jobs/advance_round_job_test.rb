require "test_helper"

class AdvanceRoundJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "timeout schedules one automatic advance twelve seconds after revealing" do
    game = build_game
    first = ready_round(game)
    ready_round(game, number: 2, status: "ready", word: "Titanic")
    travel 30.seconds do
      assert_enqueued_with job: AdvanceRoundJob, args: [ first.id ], at: Time.current + 12.seconds do
        EndRoundJob.perform_now(first.id)
      end
      assert_no_enqueued_jobs only: AdvanceRoundJob do
        EndRoundJob.perform_now(first.id)
      end
      assert_equal "revealed", first.reload.status
      assert_equal Time.current + 12.seconds, first.next_round_at
    end
  end

  test "correct guesses and host reveals both schedule the automatic transition" do
    [ :guess, :skip ].each do |reason|
      round = ready_round(build_game)
      assert_enqueued_with job: AdvanceRoundJob, args: [ round.id ], at: Time.current + 12.seconds do
        reason == :guess ? round.guess!(users(:one), round.word) : round.skip!
      end
    end
  end

  test "advance waits for the deadline and duplicate or stale jobs cannot skip rounds" do
    game = build_game
    first = ready_round(game)
    second = ready_round(game, number: 2, status: "ready", word: "Titanic")
    first.skip!
    travel 11.seconds do
      AdvanceRoundJob.perform_now(first.id)
      assert_equal first, game.reload.current_round
      assert_nil second.reload.started_at
    end
    travel 12.seconds do
      assert_enqueued_jobs 1, only: EndRoundJob do
        2.times { AdvanceRoundJob.perform_now(first.id) }
      end
      assert_equal second, game.reload.current_round
      assert_equal Time.current, second.reload.started_at
      assert_equal Time.current + 30.seconds, second.deadline
      second.skip!
      AdvanceRoundJob.perform_now(first.id)
      assert_equal second, game.reload.current_round
    end
  end

  test "a guest state poll recovers a delayed transition and returns the new round" do
    game = build_game(mode: "party", players: [ users(:one), users(:two) ])
    first = ready_round(game)
    second = ready_round(game, number: 2, status: "ready", word: "Titanic")
    first.skip!
    state = GameState.new(game, users(:two)).as_json
    assert_equal (Time.current + 12.seconds).iso8601(3), state[:round][:next_round_at]
    assert_equal first.word, state[:round][:answer]
    travel 12.seconds do
      state = GameState.new(game, users(:two)).as_json
      assert_equal second.id, state[:round][:id]
      assert_equal "playing", state[:phase]
      assert_nil state[:round][:answer]
      assert_nil state[:round][:next_round_at]
      assert_equal (Time.current + 30.seconds).iso8601(3), state[:round][:ends_at]
      AdvanceRoundJob.perform_now(first.id)
      assert_equal second, game.reload.current_round
    end
  end

  test "advancing to an unfinished drawing does not start its guessing timer" do
    game = build_game
    game.start!
    first = game.current_round
    first.update!(status: "playing", started_at: Time.current)
    first.skip!
    travel 12.seconds do
      AdvanceRoundJob.perform_now(first.id)
      second = game.reload.current_round
      assert_equal 2, second.number
      assert_equal "pending", second.status
      assert_nil second.started_at
      assert_nil second.deadline
    end
  end

  test "final results stay visible without scheduling another round" do
    game = build_game
    final = ready_round(game, number: 3)
    game.update!(active_round_number: 3)
    assert_no_enqueued_jobs only: AdvanceRoundJob do
      final.skip!
    end
    travel 30.seconds do
      AdvanceRoundJob.perform_now(final.id)
      state = GameState.new(game, users(:one)).as_json
      assert_equal "complete", state[:phase]
      assert_equal final.id, state[:round][:id]
      assert_equal final.word, state[:round][:answer]
      assert_nil state[:round][:next_round_at]
      assert_equal 1, game.rounds.count
    end
  end

  test "end jobs from earlier durations reschedule the remaining time" do
    round = ready_round(build_game)
    [ 15, 20 ].each do |seconds|
      travel seconds.seconds do
        assert_enqueued_with job: EndRoundJob, args: [ round.id ], at: round.deadline do
          EndRoundJob.perform_now(round.id)
        end
        assert_equal "playing", round.reload.status
      end
    end
    travel 30.seconds do
      EndRoundJob.perform_now(round.id)
      assert_equal "revealed", round.reload.status
    end
  end
end
