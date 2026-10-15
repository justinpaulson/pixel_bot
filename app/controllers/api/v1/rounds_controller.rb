module Api
  module V1
    class RoundsController < BaseController
      before_action :set_round
      before_action :require_host, only: %i[skip retry_drawing]
      rate_limit to: 60, within: 1.minute, only: :answer,
        with: -> { render json: { message: "Please wait, then try again.", accepted: false }, status: :too_many_requests }
      rate_limit to: 6, within: 10.minutes, only: :retry_drawing,
        with: -> { render json: { message: "Please try again later." }, status: :too_many_requests }

      def answer
        render json: @round.guess!(Current.user, params[:answer].to_s.first(120))
      end

      def drawing
        return head :not_found unless @round.svg.present? && @round.number <= @game.active_round_number && %w[playing revealed].include?(@round.status)
        render json: DrawingScene.call(@round.svg)
      end

      def skip
        @round.skip!
        render_game
      end

      def retry_drawing
        @round.retry_drawing!
        render_game
      end

      private

      def set_round
        @round = Round.find(params[:id])
        @game = @round.game
        render json: { message: "Join this room first." }, status: :forbidden unless @game.edition == 2 && @game.players.exists?(user: Current.user)
      end

      def require_host
        render json: { message: "Only the host can do that." }, status: :forbidden unless @game.created_by_id == Current.user.id && @game.active_round_number == @round.number
      end
    end
  end
end
