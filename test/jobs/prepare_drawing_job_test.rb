require "test_helper"

class PrepareDrawingJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def save_matching_drawing(round)
    source = ready_round(build_game, status: "revealed", word: round.word)
    source.update!(category: round.category, hint: round.hint, model: DrawingBot.configured_model)
    source
  end

  test "cache hits activate without waiting on or calling a drawing worker" do
    game = build_game
    game.start!
    round = game.current_round
    source = save_matching_drawing(round)
    DrawingBot.stub :new, ->(*) { flunk "Cache hits must not call the provider" } do
      assert_no_enqueued_jobs only: GenerateDrawingJob do
        assert_enqueued_jobs 1, only: EndRoundJob do
          2.times { PrepareDrawingJob.perform_now(round.id) }
        end
      end
    end
    assert_equal "playing", round.reload.status
    assert_equal SvgSanitizer.call(source.svg), round.svg
    assert_equal 0, round.generation_seconds
    assert_equal Time.current + 15.seconds, round.deadline
  end

  test "cached future rounds stay private and start a fresh timer only when advanced" do
    game = build_game
    game.start!
    first = game.current_round
    second = game.rounds.find_by(number: 2)
    save_matching_drawing(second)
    assert_no_enqueued_jobs only: EndRoundJob do
      PrepareDrawingJob.perform_now(second.id)
    end
    assert_equal "ready", second.reload.status
    assert_nil second.started_at
    state = GameState.new(game, users(:one)).as_json
    assert_nil state[:round][:image_url]
    assert_not_includes state.to_json, second.word
    travel 2.minutes do
      first.update!(status: "revealed")
      game.advance!(first.id)
      assert_equal "playing", second.reload.status
      assert_equal Time.current + 15.seconds, second.deadline
    end
  end

  test "cache misses queue three drawing requests with the active round first in priority" do
    game = build_game
    game.start!
    game.rounds.each do |round|
      priority = round.number == 1 ? 0 : 10
      assert_enqueued_with job: GenerateDrawingJob, args: [ round.id ], queue: "drawings", priority: priority do
        PrepareDrawingJob.perform_now(round.id)
      end
      assert_equal "pending", round.reload.status
      assert_nil round.started_at
    end
    assert_equal "default", PrepareDrawingJob.new.queue_name
    assert_equal "default", EndRoundJob.new.queue_name
  end

  test "completed games and stale preparation jobs cannot restart generation" do
    game = build_game
    game.start!
    round = game.current_round
    save_matching_drawing(round)
    round.update!(status: "failed")
    assert_no_enqueued_jobs do
      PrepareDrawingJob.perform_now(round.id)
    end
    assert_equal "failed", round.reload.status
    round.update!(status: "pending")
    game.update!(completed_at: Time.current)
    assert_no_enqueued_jobs do
      PrepareDrawingJob.perform_now(round.id)
      GenerateDrawingJob.perform_now(round.id)
    end
    assert_equal "pending", round.reload.status
  end
end
