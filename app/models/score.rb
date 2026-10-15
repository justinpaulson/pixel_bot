class Score < ApplicationRecord
  belongs_to :round
  belongs_to :user
  validates :user_id, uniqueness: { scope: :round_id }
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1000 }
end
