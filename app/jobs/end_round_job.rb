class EndRoundJob < ApplicationJob
  queue_as :default

  def perform(round_id)
    Round.find_by(id: round_id)&.refresh!
  end
end
