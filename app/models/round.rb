class Round < ApplicationRecord
  default_scope { order(number: :asc) }

  has_many :messages, dependent: :destroy
  belongs_to :game
  belongs_to :user

  before_validation :set_user

  before_create :set_number
  before_create :set_word

  def current_score
    Score.find_by(round: self, user: Current.user)&.points
  end

  def get_points_for_now
    # TODO: user started_at and the current time to determine a score.
  end

  private

  def set_number
    self.number = game.rounds.count + 1
  end

  def set_word
    self.word = (WORDS - game.rounds.pluck(:word)).sample.downcase
  end

  def set_user
    puts "setting the user for the round!!!0"
    puts "------------------------------------------------"
    self.user_id = game.players.where.not(id: game.rounds.pluck(:user_id)).sample.user.id
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
