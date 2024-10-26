class Game < ApplicationRecord
  before_create :set_uuid

  has_many :rounds, dependent: :destroy

  def current_round
    rounds.last || rounds.build
  end

  private

  def set_uuid
    self.id = SecureRandom.uuid if id.blank?
  end
end
