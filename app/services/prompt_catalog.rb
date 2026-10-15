class PromptCatalog
  CATEGORIES = {
    "mix" => { name: "Everything", icon: "⇄", description: "The full pop-culture lucky dip" },
    "movies" => { name: "Movies", icon: "↗", description: "Big screens. Iconic scenes." },
    "tv" => { name: "TV shows", icon: "▣", description: "Just one more episode" },
    "music" => { name: "Songs", icon: "♫", description: "You know it when you see it" },
    "stars" => { name: "Pop stars", icon: "★", description: "Legends of the main stage" },
    "games" => { name: "Video games", icon: "✚", description: "A different kind of high score" },
    "places" => { name: "Places", icon: "◎", description: "Around the world in a doodle" },
    "objects" => { name: "Objects", icon: "◇", description: "Small things. Big aha moments." }
  }.freeze

  # Curated answers keep judging fair; matching saved artwork can be reused.
  # Pipe-separated: canonical answer | accepted alternate names | delayed hint.
  DATA = {
    "movies" => <<~LIST,
      Jurassic Park||A prehistoric adventure
      Titanic||A romance at sea
      The Wizard of Oz|Wizard of Oz|A journey to a magical city
      Star Wars||A space saga
      Jaws||Trouble at the beach
      The Lion King|Lion King|An animated animal kingdom
      Harry Potter||A young wizard's world
      Back to the Future||An adventure through time
      E.T.|ET;E T the Extra Terrestrial|An unexpected visitor
      Ghostbusters|Ghost Busters|A supernatural comedy
      Finding Nemo||An underwater search
      Toy Story||A playroom adventure
      Frozen||An icy animated musical
      The Matrix|Matrix|Reality is not what it seems
      The Lord of the Rings|Lord of the Rings;LOTR|An epic fantasy quest
      Pirates of the Caribbean||A swashbuckling adventure
      King Kong||An enormous visitor to the city
      Batman|The Dark Knight|A masked city's protector
      Spider-Man|Spiderman;Spider Man|A web-slinging hero
      Indiana Jones||An archaeologist's adventure
      The Little Mermaid|Little Mermaid|A musical under the sea
      Up||An airborne animated adventure
      WALL-E|Wall E;Walle|A lonely little robot
      Ratatouille||An unlikely chef
      Shrek||A fairy-tale comedy
      The Hunger Games|Hunger Games|A dystopian competition
      Inception||A mind-bending heist
      Barbie||Life in a very pink world
      The Avengers|Avengers|A team of superheroes
      Willy Wonka|Charlie and the Chocolate Factory;Willy Wonka and the Chocolate Factory|A fantastical factory
    LIST
    "tv" => <<~LIST,
      Friends||A sitcom about six friends
      The Simpsons|Simpsons|An animated suburban family
      Stranger Things||A small town's supernatural mystery
      Game of Thrones||A battle for a fantasy throne
      The Office|Office|A workplace comedy
      Breaking Bad||A chemistry teacher's double life
      SpongeBob SquarePants|Spongebob|An underwater cartoon
      Doctor Who|Dr Who|A time-traveling science-fiction series
      The Mandalorian|Mandalorian|A space western
      Wednesday||A gothic school mystery
      Squid Game||A deadly competition series
      Ted Lasso||A fish-out-of-water sports comedy
      The Great British Bake Off|Great British Baking Show;Bake Off;GBBO|A very polite baking competition
      Sesame Street||A friendly educational neighborhood
      Scooby-Doo|Scooby Doo;Scoobydoo|A mystery-solving cartoon gang
      The Flintstones|Flintstones|A prehistoric family sitcom
      The Jetsons|Jetsons|A futuristic family sitcom
      Adventure Time||A surreal animated adventure
      Bluey||An Australian animated family
      Pokémon|Pokemon|A monster-catching adventure
      Lost||A mysterious island drama
      The Addams Family|Addams Family|A delightfully spooky family
      Teenage Mutant Ninja Turtles|Ninja Turtles;TMNT|A team of sewer-dwelling heroes
      Peppa Pig||A little pink cartoon family
    LIST
    "music" => <<~LIST,
      Yellow Submarine||A colorful Beatles song
      Purple Rain||A colorful Prince song
      Rocket Man||An Elton John song about space
      Dancing Queen||An ABBA dance-floor classic
      Firework|Fireworks|A Katy Perry anthem
      Umbrella||A Rihanna hit about shelter
      Flowers||A Miley Cyrus song about independence
      Watermelon Sugar||A sweet Harry Styles song
      Bad Romance||A Lady Gaga hit
      Single Ladies|Single Ladies Put a Ring on It|A Beyoncé dance anthem
      Blinding Lights||A neon-lit hit by The Weeknd
      Shake It Off||A Taylor Swift dance hit
      Eye of the Tiger||A motivational rock anthem
      Hotel California||An Eagles classic
      Here Comes the Sun||A hopeful Beatles song
      Stairway to Heaven||A Led Zeppelin classic
      Ring of Fire||A Johnny Cash classic
      Blackbird||A bird-inspired Beatles song
      Wrecking Ball||A Miley Cyrus hit
      Ice Ice Baby||A Vanilla Ice rap hit
      Castle on the Hill||An Ed Sheeran song
      Octopus's Garden|Octopus Garden;Octopuses Garden|An underwater Beatles song
      Walking on Sunshine||An upbeat song by Katrina and the Waves
      Sweet Caroline||A Neil Diamond singalong
    LIST
    "stars" => <<~LIST,
      Taylor Swift|Taylor|A singer known for musical eras
      Beyoncé|Beyonce|A superstar with a royal nickname
      Lady Gaga|Gaga|A pop star known for theatrical fashion
      Elton John|Sir Elton John|A piano-playing legend
      Michael Jackson|MJ|A legendary moonwalker
      Elvis Presley|Elvis|The king of rock and roll
      Dolly Parton|Dolly|A country music icon
      Prince||A purple-loving music legend
      David Bowie|Bowie|A shape-shifting glam-rock icon
      Freddie Mercury|Freddy Mercury|The frontman of Queen
      Billie Eilish|Billie|A pop singer with a distinctive oversized style
      Ariana Grande|Ariana|A singer known for a high ponytail
      Harry Styles|Harry|A flamboyant former boy-band singer
      Madonna||A boundary-pushing pop icon
      Sia||A singer who often hides behind a wig
      Daft Punk||An electronic duo in robot helmets
      KISS|Kiss band|A rock band in theatrical face paint
      Bob Marley|Marley|A reggae legend
      Willie Nelson||A country singer with signature braids
      Slash||A guitarist with a signature top hat
      Cher||A long-reigning pop diva
      Ed Sheeran|Ed|A red-haired singer-songwriter
      Bruno Mars|Bruno|A pop star with retro funk style
      Post Malone||A tattooed singer and rapper
    LIST
    "games" => <<~LIST,
      Super Mario Bros|Super Mario;Mario;Super Mario Brothers|A classic platforming adventure
      Minecraft|Mine Craft|A world built from blocks
      Tetris||A falling-block puzzle
      Pac-Man|Pacman;Pac Man|An arcade maze chase
      The Legend of Zelda|Zelda;Legend of Zelda|A fantasy adventure in Hyrule
      Sonic the Hedgehog|Sonic|A very fast blue hero
      Animal Crossing||A cozy island life
      Pokémon|Pokemon|Catch and train little creatures
      Portal||A science-fiction puzzle game
      Among Us||Find the impostor in space
      Stardew Valley||A cozy farming adventure
      Donkey Kong||An arcade classic with barrels
      Space Invaders||An alien arcade invasion
      Angry Birds||A slingshot puzzle game
      Mario Kart||A chaotic kart racer
      Frogger||An amphibian crossing a road
      Fruit Ninja||A juicy slicing game
      Plants vs. Zombies|Plants vs Zombies;Plants versus Zombies|A garden defense game
      The Sims|Sims|A life simulation
      Fall Guys||A colorful obstacle course
      Fortnite||A building and battle royale game
      Street Fighter||A classic fighting game
      Guitar Hero||A musical rhythm game
      Wii Sports||A living-room sports collection
    LIST
    "places" => <<~LIST,
      Eiffel Tower|The Eiffel Tower|A famous Paris landmark
      Statue of Liberty||A New York harbor landmark
      Great Wall of China|Great Wall|A vast historic fortification
      Taj Mahal||A marble monument in India
      Sydney Opera House||A harborside performance venue
      Big Ben||A famous London clock tower
      Golden Gate Bridge||A San Francisco landmark
      Mount Fuji|Fuji|A famous Japanese mountain
      Pyramids of Giza|Pyramids;Great Pyramid;Egyptian Pyramids|Ancient monuments in Egypt
      Stonehenge||A prehistoric stone circle
      Leaning Tower of Pisa|Pisa;Tower of Pisa|An unusually tilted Italian landmark
      Colosseum|Roman Colosseum|An ancient Roman arena
      Grand Canyon||A vast American canyon
      Mount Rushmore||A mountain with famous faces
      Venice||An Italian city of canals
      Paris||A European city of romance
      New York City|New York;NYC|The city that never sleeps
      Las Vegas|Vegas|A desert city of bright lights
      Hollywood||A famous filmmaking neighborhood
      Antarctica||The southernmost continent
      Easter Island|Rapa Nui|An island of enormous stone heads
      Niagara Falls||A famous waterfall on a border
      Santorini||A Greek island with blue domes
      Machu Picchu||An ancient city high in the Andes
    LIST
    "objects" => <<~LIST
      Astronaut||A visitor to outer space
      Bicycle|Bike|A two-wheeled ride
      Jellyfish||A drifting ocean animal
      Lighthouse||A coastal guide
      Hot Air Balloon|Balloon|A colorful way to fly
      Typewriter||An old-fashioned writing machine
      Cactus||A prickly desert plant
      Octopus||An eight-armed ocean animal
      Roller Coaster|Rollercoaster|A thrilling amusement-park ride
      Snow Globe|Snowglobe|A tiny winter scene
      Campfire|Camp Fire|The center of a camping evening
      Skateboard||A four-wheeled board
      Pineapple||A tropical fruit with a crown
      Telescope||A tool for stargazing
      Popcorn||A favorite movie snack
      Robot||A mechanical helper
      Treehouse|Tree House|A hideaway in the branches
      Dragon||A mythical fire-breather
      Unicorn||A horse with something extra
      Treasure Chest||A pirate's prized possession
      Carousel|Merry Go Round;Merry-go-round|A spinning amusement ride
      Espresso Machine|Coffee Machine;Coffee Maker|A café essential
      Gramophone|Record Player;Phonograph|A vintage music player
      Volcano||A mountain with a fiery temper
      Chameleon||A color-changing reptile
      Origami Crane|Paper Crane;Origami|A folded-paper bird
      Ferris Wheel||A giant wheel at a fair
      Submarine||An underwater vessel
      Windmill||A building powered by the breeze
      Honeybee|Bee;Honey Bee|A busy garden pollinator
    LIST
  }.freeze

  def self.entries
    @entries ||= DATA.flat_map do |category, rows|
      rows.lines.filter_map do |row|
        answer, alternatives, hint = row.strip.split("|")
        next if answer.blank?
        { category: category, word: answer, aliases: alternatives.to_s.split(";"), hint: hint }
      end
    end.freeze
  end

  def self.pick(category:, excluding: [])
    pool = entries.reject { |entry| excluding.include?(entry[:word]) }
    pool = pool.select { |entry| entry[:category] == category } unless category == "mix"
    pool.sample || raise(ArgumentError, "No unused answers in this category")
  end
end
