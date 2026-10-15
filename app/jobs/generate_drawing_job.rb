class GenerateDrawingJob < ApplicationJob
  queue_as :drawings

  def perform(round_id)
    round = Round.find_by(id: round_id)
    return unless round && round.game.edition == 2
    token = SecureRandom.uuid
    claimed = round.game.with_lock do
      round.reload
      next false unless round.status == "pending" && !round.game.completed?
      round.update!(status: "generating", generation_token: token, generation_started_at: Time.current)
      true
    end
    return unless claimed

    # Another game may have finished this answer while our job was queued.
    result = DrawingLibrary.find_for(round) || DrawingBot.new(round: round).run
    round.complete_drawing!(result, token: token)
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
