require "net/http"

class DrawingBot
  class Error < StandardError; end
  DEFAULT_MODEL = "gpt-6-astra"
  # Increment when illustration instructions change enough to invalidate saved art.
  ARTWORK_VERSION = 1

  def self.configured_model
    ENV.fetch("PIXEL_MODEL", DEFAULT_MODEL)
  end

  def initialize(round:, model: self.class.configured_model)
    @round, @model = round, model
  end

  def run
    key = ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.openai_access_token
    raise Error, "Drawing service is not configured" if key.blank?

    uri = URI("https://api.openai.com/v1/responses")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{key}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: @model, store: false, reasoning: { effort: "low" }, max_output_tokens: 9000,
      instructions: instructions,
      input: "Category: #{@round.category}. Secret answer: #{@round.word}. Context: #{@round.hint}. Fresh composition seed: #{SecureRandom.hex(8)}. Draw a new visual riddle for this answer."
    }.to_json
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 150, write_timeout: 15) { |http| http.request(request) }
    raise Error, "Drawing provider returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    raise Error, "Drawing was not completed" unless data["status"] == "completed"

    text = data.fetch("output", []).flat_map { |item| item.fetch("content", []) }.select { |item| item["type"] == "output_text" }.map { |item| item["text"] }.join
    { svg: SvgSanitizer.call(text), model: data.fetch("model", @model), artwork_version: ARTWORK_VERSION }
  rescue JSON::ParserError, Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
    raise Error, "Drawing service unavailable (#{e.class.name})"
  end

  def instructions
    <<~PROMPT
      You are Pixel, an exceptional illustrator making a visual guessing game for general audiences.
      Everyone guesses the secret answer; nobody is told it. Create a clear, delightful visual riddle.
      For a movie, show its iconic scene or 2-3 unmistakable props. For TV, use its distinctive setting or ensemble silhouettes.
      For a song, illustrate memorable imagery or a literal visual rebus of its title. For a pop star, combine recognizable hair,
      costume, instrument and stage props, not a generic singer. For an object, show its distinctive silhouette.
      Use a confident, polished editorial illustration: bold clean outlines, layered flat color, expressive shapes, thoughtful composition.
      Fill the 512 by 512 canvas with 2-4 purposeful visual clues, generous breathing room and a warm ivory background (#fffdf7).
      Make it guessable without text. No letters, numbers, words, logos, signatures, captions, or spelling the answer with shapes.
      Return ONLY a complete SVG with viewBox="0 0 512 512". Use only svg, g, path, circle, ellipse, rect, line, polygon, polyline.
      Use direct geometry and presentation attributes with solid hex fills and strokes. No text, titles, descriptions, comments,
      metadata, IDs, classes, style tags/attributes, scripts, external resources, images, use, defs, gradients, filters or animation.
      Give each new request a fresh composition. Keep the SVG compact, under 6500 output tokens. Complete all closing tags.
    PROMPT
  end
end
