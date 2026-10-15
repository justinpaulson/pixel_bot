class DrawingModels
  DEFAULT = "gpt-6-astra"
  OPTIONS = {
    "gpt-6-astra" => { name: "Astra", full_name: "GPT-6 Astra", challenge: "Easier", description: "Detailed drawings. Clearer clues.", color: "mint", preview: "artists/astra.svg" },
    "gpt-6.1-sol" => { name: "Sol", full_name: "GPT-6.1 Sol", challenge: "Balanced", description: "A little more room to wonder.", color: "ice", preview: "artists/sol.svg" },
    "gpt-6-luna" => { name: "Luna", full_name: "GPT-6 Luna", challenge: "Harder", description: "Smaller model. Wilder clues.", color: "peach", preview: "artists/luna.svg" }
  }.freeze

  def self.default
    configured = DrawingBot.configured_model
    OPTIONS.key?(configured) ? configured : DEFAULT
  end
end
