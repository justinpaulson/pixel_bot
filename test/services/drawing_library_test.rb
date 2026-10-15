require "test_helper"

class DrawingLibraryTest < ActiveSupport::TestCase
  setup do
    @source = ready_round(build_game, status: "revealed")
    @source.update!(model: DrawingBot.configured_model)
    @target = build_game.rounds.create!(user: users(:one), number: 1, word: @source.word,
      category: @source.category, hint: @source.hint)
  end

  test "reuses existing completed art and sanitizes it again" do
    @source.update!(svg: '<svg viewBox="0 0 512 512"><title>Jurassic Park</title><script>alert(1)</script><circle r="10"/></svg>')
    drawing = DrawingLibrary.find_for(@target)
    assert_equal DrawingBot.configured_model, drawing[:model]
    assert_equal DrawingBot::ARTWORK_VERSION, drawing[:artwork_version]
    assert_includes drawing[:svg], "circle"
    assert_not_includes drawing[:svg], "Jurassic"
    assert_not_includes drawing[:svg], "script"
  end

  test "requires matching answer category context model and artwork version" do
    { word: "Titanic", category: "tv", hint: "Different clue", model: "other-model",
      artwork_version: 0, status: "failed", svg: nil }.each do |attribute, changed|
      original = @source.public_send(attribute)
      @source.update!(attribute => changed)
      assert_nil DrawingLibrary.find_for(@target), "Should reject different #{attribute}"
      @source.update!(attribute => original)
    end
    @source.game.update!(edition: 1)
    assert_nil DrawingLibrary.find_for(@target)
  end

  test "skips corrupt artwork and can fall back to an older valid drawing" do
    newer = ready_round(build_game, status: "ready")
    newer.update!(model: DrawingBot.configured_model, svg: "broken XML")
    assert_equal SvgSanitizer.call(@source.svg), DrawingLibrary.find_for(@target)[:svg]
    @source.update!(svg: "also broken")
    assert_nil DrawingLibrary.find_for(@target)
  end

  test "a smaller artist never receives saved frontier art for the same answer" do
    game = build_game(drawing_model: "gpt-6-luna")
    target = game.rounds.create!(user: users(:one), number: 1, word: @source.word, category: @source.category, hint: @source.hint)
    assert_nil DrawingLibrary.find_for(target)
    source = ready_round(build_game(drawing_model: "gpt-6-luna"), status: "revealed")
    source.update!(model: "gpt-6-luna")
    drawing = DrawingLibrary.find_for(target)
    assert_equal "gpt-6-luna", drawing[:model]
    assert_equal SvgSanitizer.call(source.svg), drawing[:svg]
    assert_equal "gpt-6-astra", DrawingLibrary.find_for(@target)[:model]
  end
end
