class GamesController < ApplicationController
  def index
    @games = Game.all
  end

  def show
    @game = Game.find(params[:id])
    @current_player = @game.players.find_or_create_by(user: Current.session.user)
    @round = @game.current_round
  end

  def new
    @game = Game.new(created_by: Current.session.user)
    @round = @game.current_round
    redirect_to @game if @game.save
  end

  def start
    @game = Game.find(params[:id])
    @game.started_at = Time.now
    @game.save!
    Round.create!(game: @game)
    redirect_to @game
  end
end
