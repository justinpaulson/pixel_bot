# Keep the old job constant so previously queued jobs can drain safely on deployment.
class StartRoundJob < ApplicationJob
  queue_as :default

  def perform(round_id)
    GenerateDrawingJob.perform_later(round_id) if Round.find_by(id: round_id)&.game&.edition == 2
  end
end
