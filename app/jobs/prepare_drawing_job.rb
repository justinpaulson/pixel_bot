class PrepareDrawingJob < ApplicationJob
  queue_as :default

  def perform(round_id)
    round = Round.find_by(id: round_id)
    return unless round && round.game.edition == 2 && round.status == "pending" && !round.game.completed?

    if (drawing = DrawingLibrary.find_for(round))
      round.complete_drawing!(drawing)
    else
      priority = round.number == round.game.active_round_number ? 0 : 10
      GenerateDrawingJob.set(priority: priority).perform_later(round.id)
    end
  end
end
