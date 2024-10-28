class RoundsController < ApplicationController
  def answer
    @round = Round.find(params[:id])
    puts "this is params[:answer] #{params[:answer]}"
    puts "this is @round.word #{@round.word}"
    if @round.word == params[:answer].downcase
      Score.create!(user: Current.session.user, round: @round, points: @round.get_points_for_now)
    end
    redirect_to @round
  end
end
