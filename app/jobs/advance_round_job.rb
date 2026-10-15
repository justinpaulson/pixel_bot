class AdvanceRoundJob < ApplicationJob
  queue_as :default

  def perform(round_id)
    round = Round.find_by(id: round_id)
    round.game.advance!(round.id, automatic: true) if round&.game&.edition == 2
  end
end
