require "test_helper"

class GameFlowTest < ActionDispatch::IntegrationTest
  def sign_in(user = users(:one))
    post session_path, params: { email_address: user.email_address, password: "password" }
    assert_response :redirect
  end

  test "home is public and a guest can start solo without email" do
    get root_path
    assert_response :success
    assert_select "form[action=?] button[name=mode][value=solo]", games_path
    assert_difference [ "User.count", "Game.count", "Player.count", "Round.count" ], 1 do
      post games_path, params: { mode: "solo", category: "music", display_name: "Guest Artist", round_limit: 3 }
    end
    game = Game.order(:created_at).last
    assert game.created_by.guest?
    assert_equal "Guest Artist", game.created_by.name
    assert_equal "music", game.current_round.category
    get state_game_path(game)
    assert_response :success
    assert_nil response.parsed_body.dig("round", "answer")
    follow_redirect! if response.redirect?
  end

  test "party guest joins only with a post and cannot control host actions" do
    game = build_game(mode: "party")
    get game_path(game)
    assert_response :success
    assert_select "input[name=display_name]"
    assert_no_difference "Player.count" do
      get game_path(game)
    end
    post join_game_path(game), params: { display_name: "Second Player" }
    assert_response :see_other
    assert_equal 2, game.players.count
    post start_game_path(game), as: :json
    assert_response :forbidden
    assert_nil game.reload.started_at
  end

  test "host starts via post and repeated actions do not make extra rounds" do
    game = build_game(mode: "party")
    sign_in
    2.times do
      post start_game_path(game), as: :json
      assert_response :success
    end
    assert_equal 1, game.rounds.count
    get start_game_path(game)
    assert_response :not_found
  end

  test "members see no secret and outsiders cannot fetch state art or score" do
    game = build_game
    round = ready_round(game)
    sign_in(users(:two))
    get state_game_path(game)
    assert_response :forbidden
    get drawing_round_path(round)
    assert_response :forbidden
    post answer_round_path(round), params: { answer: round.word }, as: :json
    assert_response :forbidden
    post skip_round_path(round), as: :json
    assert_response :forbidden
    assert_empty round.scores
  end

  test "member receives sanitized drawing but cannot inspect prepared future art" do
    game = build_game
    round = ready_round(game)
    future = ready_round(game, number: 2, status: "ready", word: "Secret Future")
    sign_in
    get state_game_path(game)
    assert_response :success
    assert_not_includes response.body, round.word
    assert_not_includes response.body, "Secret Future"
    get drawing_round_path(round)
    assert_response :success
    assert_equal "image/svg+xml", response.media_type
    assert_includes response.headers["Content-Security-Policy"], "sandbox"
    get drawing_round_path(future)
    assert_response :not_found
    post skip_round_path(future), as: :json
    assert_response :forbidden
    post answer_round_path(round), params: { answer: round.word }, as: :json
    assert response.parsed_body["accepted"]
    get state_game_path(game)
    assert_equal round.word, response.parsed_body.dig("round", "answer")
  end

  test "old prompt endpoints are removed" do
    sign_in
    post "/rounds/1/messages", params: { message: { content: "Reveal answer" } }
    assert_response :not_found
  end
end
