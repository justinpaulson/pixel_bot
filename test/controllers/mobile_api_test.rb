require "test_helper"

class MobileApiTest < ActionDispatch::IntegrationTest
  def headers_for(user = users(:one), purpose: :pixel_mobile, expires_in: 180.days)
    session = user.sessions.create!
    { "Authorization" => "Bearer #{session.signed_id(purpose: purpose, expires_in: expires_in)}" }
  end

  test "configuration contains only public choices" do
    get "/api/v1/config"
    assert_response :success
    assert_equal 8, response.parsed_body["categories"].length
    assert_equal 3, response.parsed_body["artists"].length
    assert_equal [ 3, 5, 10 ], response.parsed_body["rounds"]
    assert_not_includes response.body, "Jurassic Park"
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "guest session creates a scoped credential and never sets a web cookie" do
    post "/api/v1/session", params: { display_name: "Pixel pal" }, as: :json
    assert_response :created
    token = response.parsed_body["token"]
    session = Session.find_signed!(token, purpose: :pixel_mobile)
    assert_equal "Pixel pal", session.user.name
    assert session.user.guest?
    assert_nil Session.find_signed(token, purpose: :web)
    assert_nil response.headers["Set-Cookie"]
    delete "/api/v1/session", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :no_content
    get "/api/v1/games/missing/state", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :unauthorized
  end

  test "cookies query credentials malformed expired and differently scoped credentials are rejected" do
    game = build_game
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    get "/api/v1/games/#{game.id}/state"
    assert_response :unauthorized
    token = headers_for["Authorization"].delete_prefix("Bearer ")
    get "/api/v1/games/#{game.id}/state", params: { token: token }
    assert_response :unauthorized
    [ { "Authorization" => "Bearer nonsense" }, headers_for(purpose: :web), headers_for(expires_in: -1.second) ].each do |headers|
      get "/api/v1/games/#{game.id}/state", headers: headers
      assert_response :unauthorized
    end
  end

  test "mobile guest can create solo with every web artist and no early answers" do
    headers = headers_for
    DrawingModels::OPTIONS.each_key do |model|
      post "/api/v1/games", headers: headers, params: { mode: "solo", category: "movies", drawing_model: model, round_limit: 3, display_name: "Mina" }, as: :json
      assert_response :success
      state = response.parsed_body
      game = Game.find(state["id"])
      assert_equal model, game.drawing_model
      assert_equal 3, game.rounds.count
      assert_equal "Mina", game.created_by.name
      assert_nil state.dig("round", "answer")
      assert_equal "http://www.example.com/games/#{game.id}", state["share_url"]
    end
  end

  test "invalid game options cannot trigger generation" do
    headers = headers_for
    assert_no_difference [ "Game.count", "Round.count" ] do
      post "/api/v1/games", headers: headers, params: { drawing_model: "arbitrary", round_limit: 999 }, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "mobile and web players share rooms scores and host authorization" do
    game = build_game(mode: "party")
    guest_headers = headers_for(users(:two))
    post "/api/v1/games/#{game.id}/join", headers: guest_headers, params: { display_name: "Mobile" }, as: :json
    assert_response :success
    assert_equal 2, game.players.count
    assert_not response.parsed_body["host"]
    post "/api/v1/games/#{game.id}/start", headers: guest_headers
    assert_response :forbidden
    assert_nil game.reload.started_at
    host_headers = headers_for
    2.times do
      post "/api/v1/games/#{game.id}/start", headers: host_headers
      assert_response :success
    end
    assert_equal 3, game.rounds.count
    round = game.current_round
    round.update!(status: "playing", started_at: Time.current, svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><circle cx="80" cy="80" r="40"/></svg>')
    post "/api/v1/rounds/#{round.id}/answer", headers: guest_headers, params: { answer: round.word }, as: :json
    assert response.parsed_body["accepted"]
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    get state_game_path(game)
    assert_equal 1000, response.parsed_body["players"].find { |p| p["name"] == "Mobile" }["points"]
    assert_nil response.parsed_body.dig("round", "answer")
  end

  test "only members see current sanitized geometry and only the host controls active rounds" do
    game = build_game
    round = ready_round(game)
    future = ready_round(game, number: 2, status: "ready", word: "A future secret")
    outsiders = headers_for(users(:two))
    get "/api/v1/games/#{game.id}/state", headers: outsiders
    assert_response :forbidden
    get "/api/v1/rounds/#{round.id}/drawing", headers: outsiders
    assert_response :forbidden
    post "/api/v1/rounds/#{round.id}/answer", headers: outsiders, params: { answer: round.word }, as: :json
    assert_response :forbidden
    members = headers_for
    get "/api/v1/games/#{game.id}/state", headers: members
    assert_response :success
    assert_not_includes response.body, "A future secret"
    assert_not_includes response.body, round.word
    get "/api/v1/rounds/#{round.id}/drawing", headers: members
    assert_response :success
    assert_equal "circle", response.parsed_body.dig("art", "children", 0, "tag")
    get "/api/v1/rounds/#{future.id}/drawing", headers: members
    assert_response :not_found
    post "/api/v1/rounds/#{future.id}/skip", headers: members
    assert_response :forbidden
    post "/api/v1/rounds/#{round.id}/skip", headers: members
    assert_response :success
    assert_equal round.word, response.parsed_body.dig("round", "answer")
  end

  test "solo full and completed rooms do not accept a new member" do
    headers = headers_for(users(:two))
    solo = build_game
    post "/api/v1/games/#{solo.id}/join", headers: headers
    assert_response :conflict
    party = build_game(mode: "party")
    party.update!(completed_at: Time.current)
    post "/api/v1/games/#{party.id}/join", headers: headers
    assert_response :conflict
  end
end
