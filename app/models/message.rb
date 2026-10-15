# Historical prompt records are retained; the current game never exposes them.
class Message < ApplicationRecord
  belongs_to :user
  belongs_to :round
end
