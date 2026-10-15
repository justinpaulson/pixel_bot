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

  # Server-only, authored catalog. Columns: answer | aliases | delayed hint |
  # optional private illustration brief. Existing hints remain unchanged so
  # compatible artwork stays reusable. Source/review notes: docs/prompt-catalog.md.
  DATA = CATEGORIES.keys.excluding("mix").to_h do |category|
    [ category, Rails.root.join("config/prompt_catalog/#{category}.txt").read.freeze ]
  end.freeze

  def self.records
    @records ||= DATA.flat_map do |category, rows|
      rows.lines.filter_map do |row|
        next if row.strip.empty?
        fields = row.strip.split("|", -1)
        unless fields.length.in?(3..4) && fields[0].present? && fields[2].present?
          raise ArgumentError, "Invalid #{category} catalog entry: #{fields.first}"
        end
        answer, alternatives, hint, visual_clue = fields
        { category: category, word: answer, aliases: alternatives.split(";"), hint: hint, visual_clue: visual_clue }.freeze
      end
    end.freeze
  end

  # Only persisted round attributes leave the catalog. Illustration briefs are
  # looked up by the drawing worker and never become part of the public state.
  def self.entries
    @entries ||= records.map { |record| record.except(:visual_clue).freeze }.freeze
  end

  def self.visual_clue(category:, word:)
    @visual_clues ||= records.to_h { |record| [ [ record[:category], record[:word] ], record[:visual_clue] ] }.freeze
    @visual_clues[[ category, word ]]
  end

  def self.pick(category:, excluding: [])
    pool = entries.reject { |entry| excluding.include?(entry[:word]) }
    pool = pool.select { |entry| entry[:category] == category } unless category == "mix"
    pool.sample || raise(ArgumentError, "No unused answers in this category")
  end
end
