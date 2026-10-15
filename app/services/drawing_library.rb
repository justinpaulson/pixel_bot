class DrawingLibrary
  # Completed round records are the library, so existing drawings work immediately
  # without a separate cache warm-up or exposing a public answer-to-image endpoint.
  def self.find_for(round)
    candidates = Round.joins(:game).where(games: { edition: 2 })
      .where(category: round.category, word: round.word, hint: round.hint,
        model: round.game.drawing_model, artwork_version: DrawingBot::ARTWORK_VERSION,
        status: %w[ready playing revealed])
      .where.not(id: round.id).where.not(svg: [ nil, "" ])
      .reorder(id: :desc).limit(5)

    candidates.each do |candidate|
      begin
        return { svg: SvgSanitizer.call(candidate.svg), model: candidate.model, artwork_version: candidate.artwork_version }
      rescue SvgSanitizer::Invalid
        # Skip damaged historical art and try an older illustration or generate anew.
        Rails.logger.warn("Pixel skipped invalid saved drawing round=#{candidate.id}")
      end
    end
    nil
  end
end
