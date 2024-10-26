class GamesController < ApplicationController
  def index
    @games = Game.all
  end

  def show
    @game = Game.find(params[:id])
    @round = @game.current_round
  end

  def new
    @game = Game.new
    @round = @game.current_round
    redirect_to @game if @game.save
  end
end
