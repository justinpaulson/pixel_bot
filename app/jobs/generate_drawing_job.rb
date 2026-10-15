class GenerateDrawingJob < ApplicationJob
  queue_as :default

  def perform(round_id)
    round = Round.find_by(id: round_id)
    return unless round && round.game.edition == 2
    token = SecureRandom.uuid
    claimed = round.game.with_lock do
      round.reload
      next false unless round.status == "pending"
      round.update!(status: "generating", generation_token: token, generation_started_at: Time.current)
      true
    end
    return unless claimed

    result = DrawingBot.new(round: round).run
    applied = round.game.with_lock do
      round.reload
      next false unless round.status == "generating" && round.generation_token == token
      round.update!(svg: result.fetch(:svg), model: result.fetch(:model), status: "ready",
        generation_seconds: Time.current - round.generation_started_at, generation_token: nil, error_message: nil)
      round.activate! if round.game.active_round_number == round.number
      round.status == "playing"
    end
    if applied
      EndRoundJob.set(wait_until: round.deadline).perform_later(round.id)
      round.game.prepare_next!
    end
  rescue StandardError => e
    # Provider payloads can contain credentials or secret answers. Log only the class and record id.
    Rails.logger.error("Pixel generation failed round=#{round_id} error=#{e.class.name}")
    round&.game&.with_lock do
      round.reload
      if round.status == "generating" && round.generation_token == token
        round.update!(status: "failed", generation_token: nil, error_message: "Couldn't finish the drawing. Try again.")
      end
    end
  end
end
