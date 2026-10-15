class GamesController < ApplicationController
  allow_unauthenticated_access only: %i[index show create join]
  before_action :resume_session, only: %i[index show create join]
  before_action :set_game, except: %i[index create]
  before_action :require_membership, only: %i[state start advance]
  before_action :require_host, only: %i[start advance]
  rate_limit to: 12, within: 1.hour, only: :create, with: -> { redirect_to root_path, alert: "That's a lot of games! Please try again in a little while." }
  rate_limit to: 30, within: 5.minutes, only: :join, with: -> { redirect_to root_path, alert: "Please wait a moment before joining again." }

  def index
    @categories = PromptCatalog::CATEGORIES
  end

  def create
    ensure_player_identity!
    @game = Game.new(created_by: Current.user, category: params[:category].presence || "mix", mode: params[:mode].presence || "solo", round_limit: params[:round_limit].presence || 5, edition: 2)
    if @game.save
      @game.join!(Current.user)
      @game.start! if @game.mode == "solo"
      redirect_to @game, status: :see_other
    else
      redirect_to root_path, alert: @game.errors.full_messages.to_sentence
    end
  end

  def show
    @member = Current.user && @game.players.exists?(user: Current.user)
  end

  def join
    ensure_player_identity!
    if @game.join!(Current.user)
      redirect_to @game, status: :see_other
    else
      redirect_to root_path, alert: "This room is full, finished, or reserved for solo play. Start a new game!"
    end
  end

  def state
    response.headers["Cache-Control"] = "no-store"
    render json: GameState.new(@game, Current.user)
  end

  def start
    @game.start!
    mutation_response(@game)
  end

  def advance
    @game.advance!(params[:round_id])
    mutation_response(@game)
  end

  private

  def set_game
    @game = Game.find(params[:id])
  end

  def require_membership
    head :forbidden unless @game.edition == 2 && @game.players.exists?(user: Current.user)
  end

  def require_host
    head :forbidden unless @game.created_by_id == Current.user.id
  end

  def ensure_player_identity!
    name = params[:display_name].to_s.strip.truncate(24, omission: "").presence || Current.user&.name || "Guest #{SecureRandom.random_number(900) + 100}"
    if Current.user
      Current.user.update!(display_name: name)
    else
      user = User.create!(email_address: "guest-#{SecureRandom.uuid}@pixel.invalid", password: SecureRandom.hex(32), display_name: name, guest: true)
      start_new_session_for(user)
    end
  end
end
