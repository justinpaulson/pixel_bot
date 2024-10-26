class RoundsController < ApplicationController
  def answer
    @round = Round.find(params[:id])
    if @round.word == params[:answer].downcase && @round.running?
      Score.create!(user: Current.session.user, round: @round, points: @round.get_points_for_now)
    end
    redirect_to @round.game
  end
end
