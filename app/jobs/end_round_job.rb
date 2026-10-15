class EndRoundJob < ApplicationJob
  queue_as :default

  def perform(round_id)
    round = Round.find_by(id: round_id)
    return unless round
    round.refresh!
    # A job scheduled before a duration change may arrive before the new deadline.
    self.class.set(wait_until: round.deadline).perform_later(round.id) if round.reload.running?
  end
end
