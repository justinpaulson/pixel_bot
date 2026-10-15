class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern

  private

  def mutation_response(game)
    if request.format.json?
      render json: { ok: true }
    else
      redirect_to game, status: :see_other
    end
  end
end
