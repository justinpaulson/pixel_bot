require "test_helper"

class DrawingBotTest < ActiveSupport::TestCase
  def fake_request(body, status: Net::HTTPOK, &check)
    response = status.new("1.1", status == Net::HTTPOK ? "200" : "429", "test")
    response.define_singleton_method(:body) { body.to_json }
    http = Object.new
    http.define_singleton_method(:request) do |request|
      check&.call(request)
      response
    end
    ->(*_args, **_options, &block) { block.call(http) }
  end

  test "uses Responses with compatible reasoning and sanitizes output" do
    round = ready_round(build_game)
    result = { status: "completed", model: "gpt-6-astra", output: [ { type: "message", content: [ { type: "output_text", text: '<svg viewBox="0 0 512 512"><title>Jurassic Park</title><circle r="10"/></svg>' } ] } ] }
    transport = fake_request(result) do |request|
      assert_equal "/v1/responses", request.path
      payload = JSON.parse(request.body)
      assert_equal "gpt-6-astra", payload["model"]
      assert_equal false, payload["store"]
      assert_equal "low", payload.dig("reasoning", "effort")
      assert_not payload.key?("temperature")
      assert_includes payload["input"], "Jurassic Park"
    end
    # CI has no production credentials. Use a dummy test value, never a live key.
    original = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-only"
    Net::HTTP.stub :start, transport do
      output = DrawingBot.new(round: round).run
      assert_equal "gpt-6-astra", output[:model]
      assert_not_includes output[:svg], "Jurassic Park"
    end
  ensure
    ENV["OPENAI_API_KEY"] = original
  end

  test "incomplete responses are not displayed as drawings" do
    original = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-only"
    round = ready_round(build_game)
    Net::HTTP.stub :start, fake_request({ status: "incomplete", output: [] }) do
      assert_raises(DrawingBot::Error) { DrawingBot.new(round: round).run }
    end
    Net::HTTP.stub :start, fake_request({ error: { message: "private provider details" } }, status: Net::HTTPTooManyRequests) do
      error = assert_raises(DrawingBot::Error) { DrawingBot.new(round: round).run }
      assert_not_includes error.message, "private"
    end
  ensure
    ENV["OPENAI_API_KEY"] = original
  end

  test "each artist sends the room's saved model to the provider including after a default change" do
    original_key, original_model = ENV.values_at("OPENAI_API_KEY", "PIXEL_MODEL")
    ENV["OPENAI_API_KEY"] = "test-only"
    DrawingModels::OPTIONS.each_key do |model|
      round = ready_round(build_game(drawing_model: model))
      ENV["PIXEL_MODEL"] = model == "gpt-6-astra" ? "gpt-6-luna" : "gpt-6-astra"
      response = { status: "completed", model: model, output: [ { content: [ { type: "output_text", text: '<svg viewBox="0 0 512 512"><circle r="10"/></svg>' } ] } ] }
      transport = fake_request(response) { |request| assert_equal model, JSON.parse(request.body)["model"] }
      Net::HTTP.stub :start, transport do
        assert_equal model, DrawingBot.new(round: round).run[:model]
      end
    end
  ensure
    ENV["OPENAI_API_KEY"], ENV["PIXEL_MODEL"] = original_key, original_model
  end
end
