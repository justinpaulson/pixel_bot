class StartRoundJob < ApplicationJob
  queue_as :default

  def perform(round_id)
    round = Round.find(round_id)
    return unless round # Guard against deleted rounds
    return if round.running? # Guard against double starting

    round.start!

    # Schedule the end of round job
    EndRoundJob.set(wait: 1.minutes).perform_later(round_id)
  end
end
