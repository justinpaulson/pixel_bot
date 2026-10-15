class GameState
  def initialize(game, user)
    @game, @user = game, user
  end

  def as_json(*)
    round = @game.current_round
    round&.refresh!
    @game.reload
    scores = Score.joins(:round).where(rounds: { game_id: @game.id }).group(:user_id).sum(:points)
    solved = round ? round.scores.pluck(:user_id) : []
    {
      phase: @game.completed? ? "complete" : (round&.status || "lobby"),
      host: @game.created_by_id == @user.id, mode: @game.mode, round_limit: @game.round_limit,
      server_time: Time.current.iso8601(3), round_duration_seconds: Round::DURATION.to_i,
      players: @game.players.includes(:user).map { |p| { name: p.user.name, me: p.user_id == @user.id, points: scores.fetch(p.user_id, 0), solved: solved.include?(p.user_id) } }.sort_by { |p| -p[:points] },
      round: round && {
        id: round.id, number: round.number, category: PromptCatalog::CATEGORIES.dig(round.category, :name),
        status: round.status, ends_at: round.deadline&.iso8601(3), solved: solved.include?(@user.id),
        image_url: round.svg.present? ? Rails.application.routes.url_helpers.drawing_round_path(round) : nil,
        hint: round.started_at && Time.current >= round.started_at + Round::HINT_DELAY ? round.hint : nil,
        answer: round.status == "revealed" ? round.word : nil, error: round.status == "failed" ? round.error_message : nil
      },
      gallery: @game.rounds.where(status: "revealed").map { |r| { number: r.number, answer: r.word, image_url: Rails.application.routes.url_helpers.drawing_round_path(r) } }
    }
  end
end
