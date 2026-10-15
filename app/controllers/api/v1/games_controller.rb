module Api
  module V1
    class GamesController < BaseController
      before_action :set_game, except: :create
      before_action :require_membership, only: %i[state start advance]
      before_action :require_host, only: %i[start advance]
      rate_limit to: 12, within: 1.hour, only: :create,
        with: -> { render json: { message: "Game limit reached. Try again later." }, status: :too_many_requests }
      rate_limit to: 30, within: 5.minutes, only: :join,
        with: -> { render json: { message: "Please wait before joining again." }, status: :too_many_requests }

      def create
        update_nickname
        @game = Game.create!(created_by: Current.user, edition: 2,
          mode: params[:mode].presence || "solo", category: params[:category].presence || "mix",
          round_limit: params[:round_limit].presence || 5, drawing_model: params[:drawing_model].presence || DrawingModels.default)
        @game.join!(Current.user)
        @game.start! if @game.mode == "solo"
        render_game
      end

      def join
        update_nickname
        if @game.join!(Current.user)
          render_game
        else
          render json: { message: "Room full or unavailable." }, status: :conflict
        end
      end

      def state
        render_game
      end

      def start
        @game.start!
        render_game
      end

      def advance
        @game.advance!(params[:round_id])
        render_game
      end

      private

      def set_game
        @game = Game.find(params[:id])
      end

      def require_membership
        render json: { message: "Join this room first." }, status: :forbidden unless @game.edition == 2 && @game.players.exists?(user: Current.user)
      end

      def require_host
        render json: { message: "Only the host can do that." }, status: :forbidden unless @game.created_by_id == Current.user.id
      end
    end
  end
end
