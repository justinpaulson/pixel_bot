require "test_helper"

class GenerateDrawingJobTest < ActiveSupport::TestCase
  test "generates once starts clock after the response and prepares only one round ahead" do
    game = build_game
    game.start!
    first = game.current_round
    bot = Minitest::Mock.new
    bot.expect :run, { svg: '<svg viewBox="0 0 512 512"><circle r="10"/></svg>', model: "test-model" }
    DrawingBot.stub :new, bot do
      GenerateDrawingJob.perform_now(first.id)
      GenerateDrawingJob.perform_now(first.id)
    end
    bot.verify
    assert_equal "playing", first.reload.status
    assert first.started_at
    assert_equal 2, game.rounds.count
    second = game.rounds.find_by(number: 2)
    DrawingBot.stub :new, Struct.new(:run).new({ svg: first.svg, model: "test-model" }) do
      GenerateDrawingJob.perform_now(second.id)
    end
    assert_equal "ready", second.reload.status
    assert_nil second.started_at
    assert_equal first, game.reload.current_round
    assert_equal 2, game.rounds.count
  end

  test "provider failures become recoverable without leaking the provider message" do
    game = build_game
    game.start!
    bot = Object.new
    def bot.run
      raise DrawingBot::Error, "sensitive provider response"
    end
    DrawingBot.stub :new, bot do
      GenerateDrawingJob.perform_now(game.current_round.id)
    end
    round = game.current_round.reload
    assert_equal "failed", round.status
    assert_nil round.started_at
    assert_not_includes round.error_message, "sensitive"
    assert round.retry_drawing!
  end

  test "late generation cannot overwrite a timeout or a newer attempt" do
    game = build_game
    game.start!
    round = game.current_round
    bot = Object.new
    bot.define_singleton_method(:run) do
      round.update!(status: "failed", generation_token: nil)
      { svg: "stale", model: "test-model" }
    end
    DrawingBot.stub :new, bot do
      GenerateDrawingJob.perform_now(round.id)
    end
    assert_equal "failed", round.reload.status
    assert_nil round.svg
  end
end
