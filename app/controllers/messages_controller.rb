class MessagesController < ApplicationController
  def index
    @messages = Round.find(params[:round_id]).messages
  end

  def create
    @round = Round.find(params[:round_id])

    ai_response = DrawingBot.new(round: @round).response(message_params[:content])

    @message = Message.create(message_params.merge(round: @round, user: Current.session.user))

    @message.image_content = ai_response

    @message.save
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
