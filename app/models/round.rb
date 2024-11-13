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
    StartRoundJob.set(wait: 10.seconds).perform_later(id)
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
    Airplane Anchor Angel Ant Apple Armor Arrow
    Bacon Backpack Bag Balloon Baseball Basket Basketball Bat
    Beach Bear Beaver Bed Bee Bell Belt Bench Berry Bicycle Bird
    Blanket Boat Bone Book Boot Bottle Bowl Brain Bridge
    Brush Bubble Bucket Bug Button Butterfly
    Cactus Cage Calculator Camera Candle Candy Car Carrot Castle
    Cat Chain Chair Cheese Chess Chicken Church Clock Cloud Clover Coin
    Compass Computer Cookie Cow Crayon Crown Cup
    Dart Diamond Dice Dinosaur Dolphin Door Dragon Dress Drill Drum
    Duck Dumbbell
    Eagle Ear Egg Elephant Envelope Eye
    Fan Feather Fence Fire Fish Flag Flashlight Flower Foot
    Fork Fox Frog
    Gate Ghost Giraffe Globe Glove Grape Goat Guitar
    Hammer Hand Harbor Hat Heart Helicopter Hook Horse Hourglass House
    Ice Igloo Island
    Jacket Jar Jellyfish Jewelry Juggler
    Kangaroo Key Kite Knife Knight
    Ladder Lamp Leaf Leg Lemon Lighthouse Lightning Lion Lock
    Magnifier Map Mask Medal Microscope Mirror Monkey Moon Mountain Mouse Mushroom
    Nail Necklace Nest Net
    Octopus Onion Owl
    Paint Palette Palm Panda Parachute Peacock Pen
    Pencil Penguin Piano Pie Pig Pillow Pineapple Pipe Pizza Plant
    Pond Present Pretzel Printer Puzzle Pyramid
    Queen Quill
    Rabbit Rainbow Rake Ring River Robot Rocket Rose Ruler
    Sailboat Salt Sandwich Satellite Saw Saxophone Scale Scarf
    Scissors Scorpion Screw Seahorse Seal Shell Shield Ship Shirt Shoe
    Shovel Skateboard Skyscraper Snail Snake Snowflake Soap
    Spaceship Spider Spoon Spring Stopwatch Storm Sun Sword
    Table Target Tea Telescope Television Tent Thermometer Thread
    Tiger Toaster Toilet Tomato Tooth Torch Tornado Tower
    Train Tree Trophy Truck Tuba Turtle
    Umbrella Unicorn
    Vase Violin Volcano
    Waffle Wallet Watch Waterfall Wave Web Whale Wheel Window
    Wizard Wolf
    Zebra Zipper
  )
end
