class Message < ApplicationRecord
  belongs_to :user
  belongs_to :round

  broadcasts_to ->(message) { [message.round, "messages"] }, action: :append, target: :messages
end
