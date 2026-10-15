class RoundsController < ApplicationController
  before_action :set_round
  before_action :require_host, only: %i[skip retry_drawing]
  rate_limit to: 60, within: 1.minute, only: :answer, with: -> { render json: { message: "Please wait, then try again.", accepted: false }, status: :too_many_requests }
  rate_limit to: 6, within: 10.minutes, only: :retry_drawing, with: -> { head :too_many_requests }

  def answer
    response.headers["Cache-Control"] = "no-store"
    render json: @round.guess!(Current.user, params[:answer].to_s.first(120))
  end

  def drawing
    return head :not_found unless @round.svg.present? && @round.number <= @round.game.active_round_number && %w[playing revealed].include?(@round.status)
    response.headers["Content-Security-Policy"] = "default-src 'none'; sandbox"
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    # Revalidate on delivery as defense in depth; this endpoint never returns raw model content.
    send_data SvgSanitizer.call(@round.svg), type: "image/svg+xml", disposition: "inline"
  end

  def skip
    @round.skip!
    mutation_response(@round.game)
  end

  def retry_drawing
    @round.retry_drawing!
    mutation_response(@round.game)
  end

  private

  def set_round
    @round = Round.find(params[:id])
    head :forbidden unless @round.game.edition == 2 && @round.game.players.exists?(user: Current.user)
  end

  def require_host
    head :forbidden unless @round.game.created_by_id == Current.user.id && @round.game.active_round_number == @round.number
  end
end
