module Api
  module V1
    # Native clients use an explicit bearer credential, never ambient cookies.
    # Web controllers retain their existing session and CSRF protection.
    class BaseController < ActionController::API
      before_action :disable_caching
      before_action :authenticate_mobile_session

      rescue_from ActiveRecord::RecordNotFound do
        render json: { message: "Game unavailable." }, status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do |error|
        render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      private

      def authenticate_mobile_session
        token = request.authorization.to_s.match(/\ABearer (.+)\z/)&.captures&.first
        Current.session = token && Session.find_signed(token, purpose: :pixel_mobile)
        render json: { message: "Please reconnect." }, status: :unauthorized unless Current.session
      end

      def disable_caching
        response.headers["Cache-Control"] = "no-store"
      end

      def render_game
        render json: GameState.new(@game, Current.user).as_json.merge(id: @game.id, share_url: game_url(@game))
      end

      def update_nickname
        name = params[:display_name].to_s.strip.first(24)
        Current.user.update!(display_name: name) if name.present?
      end
    end
  end
end
