module Api
  module V1
    class ConfigController < BaseController
      skip_before_action :authenticate_mobile_session

      def show
        render json: {
          categories: PromptCatalog::CATEGORIES.map { |id, entry| { id: id, name: entry[:name] } },
          artists: DrawingModels::OPTIONS.map { |id, entry| { id: id, name: entry[:name], challenge: entry[:challenge] } },
          default_artist: DrawingModels.default,
          rounds: [ 3, 5, 10 ], max_players: 12
        }
      end
    end
  end
end
