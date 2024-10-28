class Game < ApplicationRecord
  before_create :set_uuid

  has_many :players, dependent: :destroy
  has_many :rounds, dependent: :destroy

  belongs_to :created_by, class_name: "User"

  def current_round
    rounds.last || false
  end

  private

  def set_uuid
    self.id = SecureRandom.uuid if id.blank?
  end
end
