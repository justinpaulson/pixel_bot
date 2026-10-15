module Api
  module V1
    class SessionsController < BaseController
      skip_before_action :authenticate_mobile_session, only: :create
      rate_limit to: 30, within: 1.hour, only: :create,
        with: -> { render json: { message: "Please try again later." }, status: :too_many_requests }

      def create
        name = params[:display_name].to_s.strip.first(24).presence || "Guest #{SecureRandom.random_number(900) + 100}"
        user = User.create!(email_address: "guest-#{SecureRandom.uuid}@pixel.invalid", password: SecureRandom.hex(32), display_name: name, guest: true)
        mobile_session = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
        render json: { token: mobile_session.signed_id(purpose: :pixel_mobile, expires_in: 180.days), name: user.name }, status: :created
      end

      def destroy
        Current.session.destroy!
        head :no_content
      end
    end
  end
end
