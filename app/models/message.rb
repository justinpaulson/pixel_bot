class Message < ApplicationRecord
  belongs_to :user
  belongs_to :round

  broadcasts_to ->(message) { [ message.round, "messages" ] }, inserts_by: :prepend, target: "carousel-container"
end
