  WORDS = %w(
    Airplane Alarm Anchor Angel Antenna Apple Armor Arrow Astronaut
    Bacon Backpack Bag Balance Balloon Bamboo Baseball Basket Basketball Bat
    Beach Bear Beaver Bed Bee Beetle Bell Belt Bench Berry Bicycle Bird
    Blanket Boat Bone Book Boot Bottle Bowl Box Brain Branch Bridge
    Brush Bubble Bucket Button Butterfly
    Cactus Cage Calculator Camera Candle Candy Car Card Carrot Cart Castle
    Cat Chain Chair Cheese Chess Chicken Church Clock Cloud Clover Coin
    Compass Computer Cookie Coral Cow Crayon Cross Crown Crystal Cube
    Cup Curtain
    Dart Diamond Dice Dinosaur Dolphin Door Dragon Drawer Dress Drill Drum
    Duck Dumbbell
    Eagle Ear Egg Elephant Envelope Eye
    Fan Feather Fence Fire Fish Flag Flame Flashlight Flower Footprint
    Fork Fox Frog
    Gate Ghost Giraffe Glass Globe Glove Grape Goat Guitar
    Hammer Hand Harbor Hat Heart Helicopter Hook Horse Hourglass House
    Ice Igloo Iron Island
    Jacket Jar Jellyfish Jewelry Juggler
    Kangaroo Key Kite Knife Knight
    Ladder Lamp Leaf Leg Lemon Lighthouse Lightning Lion Lock
    Magnifier Map Mask Medal Microscope Mirror Monkey Moon Mountain Mouse
    Mushroom Music
    Nail Necklace Needle Nest Net
    Octopus Onion Owl
    Paddle Paint Palette Palm Panda Paper Parachute Peacock Pearl Pen
    Pencil Penguin Piano Pie Pig Pillow Pineapple Pipe Pizza Plant
    Plate Pond Present Pretzel Printer Puzzle Pyramid
    Queen Quill
    Rabbit Rainbow Rake Ram Record Ring River Robot Rocket Rose Ruler
    Sailboat Salt Sand Sandwich Satellite Saw Saxophone Scale Scarf School
    Scissors Scorpion Screw Seahorse Seal Shell Shield Ship Shirt Shoe
    Shovel Skateboard Ski Skyscraper Slice Snail Snake Snowflake Soap
    Socket Spaceship Spider Spoon Spring Square Star Stopwatch Storm Sun
    Sword
    Table Tape Target Tea Telescope Television Tent Thermometer Thread
    Throne Tiger Toaster Toe Toilet Tomato Tooth Torch Tornado Tower
    Train Tree Triangle Trophy Truck Tuba Tunnel Turtle
    Umbrella Unicorn
    Vase Violin Volcano
    Waffle Wall Wallet Watch Waterfall Wave Web Whale Wheel Window
    Wing Wizard Wolf
    Yarn Yoyo
    Zebra Zipper Zoo
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
