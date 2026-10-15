class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :scores, dependent: :destroy
  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :display_name, length: { maximum: 24 }

  def name
    display_name.presence || "Player #{id}"
  end
end
