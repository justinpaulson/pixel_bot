class Round < ApplicationRecord
  default_scope { order(number: :asc) }

  has_many :messages, dependent: :destroy
  has_many :scores, dependent: :destroy
  belongs_to :game
  belongs_to :user

  before_validation :set_user

  before_create :set_number
  before_create :set_word

  after_create_commit -> {
    broadcast_new_round
    StartRoundJob.set(wait: 20.seconds).perform_later(id)
  }

  def current_score
    Score.find_by(round: self, user: Current.user)&.points
  end

  def get_points_for_now
    # TODO: use started_at and the current time to determine a score with one minute being the max time and linear from
    # 0 to 100 points with 100 at 0 seconds and 0 at 60 seconds
    (100 - (Time.now - started_at) * 100 / 60).to_i
  end

  def start!
    update!(started_at: Time.now)

    game.players.each do |player|
      broadcast_replace_to [game, player.user, "round"],
        target: "round",
        locals: { round: self, game: self.game, user: player.user }
    end
  end

  def running?
    started_at.present? && started_at > 1.minutes.ago
  end

  def previous_word
    game.rounds.where("number < ?", number).last&.word
  end

  def previous_round
    game.rounds.where("number < ?", number).last
  end

  def average_score
    (scores.sum(:points) / (game.players.count - 1)).to_i
  end

  private

  def broadcast_new_round
    self.game.players.each do |player|
      broadcast_replace_to [self.game, player.user, "round"], target: "round", partial: "rounds/round", locals: { round: self, game: self.game, user: player.user }
    end
  end

  def set_number
    self.number = game.rounds.count + 1
  end

  def set_word
    self.word = (WORDS - game.rounds.pluck(:word)).sample.downcase
  end

  def set_user
    until self.user_id
      id = game.players.sample.user.id
      next if game.rounds.where(user_id: id).exists?
      self.user_id = id
    end
  end

  WORDS = %w(
    Dog
    Cat
    Fish
    Bird
    Elephant
    Lion
    Turtle
    Owl
    Snake
    Dolphin
    Butterfly
    Kangaroo
    Penguin
    Squirrel
    Tiger
    Lamp
    Chair
    Table
    Sofa
    Bed
    Clock
    Mirror
    Vase
    Shelf
    Pillow
    Blanket
    Mug
    Plate
    Spoon
    Toothbrush
    Apple
    Banana
    Burger
    Pizza
    Ice cream
    Carrot
    Hotdog
    Cake
    Cookie
    Orange
    Sandwich
    Candy
    Grape
    Lemon
    Pineapple
    Tree
    Flower
    Mountain
    River
    Sun
    Cloud
    Rainbow
    Snowflake
    Lightning
    Beach
    Leaf
    Volcano
    Ocean
    Moon
    Star
    Car
    Bus
    Bike
    Plane
    Train
    Boat
    Motorcycle
    Tractor
    Scooter
    Helicopter
    Submarine
    Skateboard
    Spaceship
    Taxi
    Truck
    Hat
    Shirt
    Pants
    Shoes
    Gloves
    Belt
    Sunglasses
    Tie
    Scarf
    Purse
    Backpack
    Umbrella
    Watch
    Boots
    Suit
    Phone
    Computer
    Laptop
    Tablet
    Headphones
    Camera
    Mouse
    Keyboard
    Printer
    Microphone
    Television
    Remote
    Drone
    Smartwatch
    Flashlight
    Game Controller
    Baseball
    Bat
    Skate
    Bicycle
    Kite
    Soccer ball
    Basketball
    Tennis racket
    Paintbrush
    Guitar
    Drum
    Trumpet
    Violin
    Puzzle
    Book
    Hammer
    Screwdriver
    Wrench
    Drill
    Saw
    Axe
    Scissors
    Tape
    Nail
    Pliers
    Shovel
    Rake
    Ladder
    Toolbelt
    Sandpaper
  )
end
