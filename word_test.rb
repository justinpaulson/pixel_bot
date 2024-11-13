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

# Find duplicates
duplicates = WORDS.group_by(&:itself).select { |k, v| v.length > 1 }.keys

puts "Total number of words: #{WORDS.length}"
puts "\nDuplicate words found:"
if duplicates.empty?
  puts "None"
else
  duplicates.each { |word| puts "- #{word} (appears #{WORDS.count(word)} times)" }
end
