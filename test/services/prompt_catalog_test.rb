require "test_helper"

class PromptCatalogTest < ActiveSupport::TestCase
  test "expanded categories contain hundreds of usable distinct answers" do
    minimums = { "music" => 450, "movies" => 300, "tv" => 300, "games" => 450 }
    PromptCatalog.records.group_by { |entry| entry[:category] }.each do |category, records|
      assert_operator records.length, :>=, minimums.fetch(category, 24)
      accepted = {}
      records.each do |record|
        assert record[:hint].present?, record[:word]
        assert_operator record[:word].length, :<=, 120
        [ record[:word], *record[:aliases] ].each do |answer|
          normalized = AnswerMatcher.normalize(answer)
          assert normalized.present?, answer
          assert AnswerMatcher.match?(answer, [ record[:word], *record[:aliases] ]), answer
          assert_includes [ nil, record[:word] ], accepted[normalized], "Ambiguous #{category} answer: #{answer}"
          accepted[normalized] = record[:word]
        end
      end
    end
  end

  test "every expansion has a private composition and only round attributes are selected" do
    original_sizes = { "movies" => 30, "tv" => 24, "music" => 24, "stars" => 24, "games" => 24, "places" => 24, "objects" => 30 }
    PromptCatalog.records.group_by { |record| record[:category] }.each do |category, records|
      records.drop(original_sizes.fetch(category)).each do |record|
        assert record[:visual_clue].present?, "Missing illustration brief for #{record[:word]}"
      end
    end
    PromptCatalog.entries.each do |entry|
      assert_equal %i[aliases category hint word], entry.keys.sort
    end
    assert_includes PromptCatalog.visual_clue(category: "music", word: "Espresso"), "espresso cup"
    assert_nil PromptCatalog.visual_clue(category: "movies", word: "Espresso")
    assert_nil PromptCatalog.visual_clue(category: "music", word: "Historical answer no longer in the catalog")
  end

  test "new songs have dated top ten evidence and retain their accepted chart titles" do
    evidence = Rails.root.join("docs/prompt-catalog/music-chart-evidence.tsv").read.lines.drop(1).map { |line| line.chomp.split("\t") }
    songs = PromptCatalog.records.select { |record| record[:category] == "music" && record[:visual_clue].present? }
    assert_equal songs.pluck(:word).sort, evidence.map(&:first).sort
    evidence.each do |answer, chart_title, artist, first_top_ten, peak|
      entry = songs.find { |song| song[:word] == answer }
      assert artist.present?, answer
      assert Date.iso8601(first_top_ten).between?(Date.new(1986, 10, 15), Date.new(2026, 10, 15)), answer
      assert peak.to_i.between?(1, 10), answer
      assert AnswerMatcher.match?(chart_title, [ entry[:word], *entry[:aliases] ]), chart_title
    end
    assert_equal (1986..2026).to_a, evidence.map { |row| Date.iso8601(row[3]).year }.uniq.sort
  end

  test "category selection excludes used answers and fails explicitly when exhausted" do
    %w[music movies tv games mix].each do |category|
      pool = PromptCatalog.entries.select { |entry| category == "mix" || entry[:category] == category }
      remaining = pool.last[:word]
      excluded = pool.pluck(:word).reject { |word| word == remaining }
      assert_equal remaining, PromptCatalog.pick(category: category, excluding: excluded)[:word]
      assert_raises(ArgumentError) { PromptCatalog.pick(category: category, excluding: pool.pluck(:word)) }
    end
  end

  test "private illustration instructions never enter game state even after reveal" do
    game = build_game
    entry = PromptCatalog.entries.find { |record| record[:category] == "movies" && record[:word] == "Spirited Away" }
    round = game.rounds.create!(entry.merge(user: game.created_by, number: 1, status: "playing", started_at: Time.current))
    clue = PromptCatalog.visual_clue(category: round.category, word: round.word)
    assert clue.present?
    state = GameState.new(game, game.created_by).as_json
    assert_nil state.dig(:round, :answer)
    assert_not_includes state.to_json, clue
    round.reveal!
    state = GameState.new(game, game.created_by).as_json
    assert_equal "Spirited Away", state.dig(:round, :answer)
    assert_not_includes state.to_json, clue
    assert_not_includes state.to_json, "visual_clue"
  end
end
