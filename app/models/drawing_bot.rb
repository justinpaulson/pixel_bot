class DrawingBot < RubyBots::OpenAITool
  def initialize(round:)
    @round = round
    @messages = @round.messages.map do |message|
      [
        { role: :user, content: message.content },
        { role: :assistant, content: message.image_content }
      ]
    end.flatten
    super(name: "Pixel Bot", description: "A bot that draws SVGs.")
  end

  def client
    puts "We are setting access token to: #{Rails.application.credentials.openai_access_token}"
    @client ||= OpenAI::Client.new(access_token: Rails.application.credentials.openai_access_token)
  end

  def default_params
    { model: "gpt-4o" }
  end

  def system_instructions
    "You are an AI artist tasked with creating and modifying SVG images based on user descriptions for a Pictionary-style game. Your role is to interpret the user's prompts and generate or alter SVG code accordingly.

Guidelines for interpretation:
- Focus on the key elements described by the user
- Keep the drawings simple and recognizable
- Use basic shapes (circles, rectangles, lines, paths) to create the image
- Interpret colors, sizes, and positions as described by the user

When creating or modifying SVG code:
- Use a 300x300 viewport size
- Utilize appropriate SVG elements and attributes
- Ensure all shapes are properly closed and valid
- Use descriptive class names for major elements

Output format:
- Respond with only the SVG code, nothing else
- Enclose the entire SVG code within <svg></svg> tags
- Do not include any explanations or comments outside the SVG code

Interpret the description and create an SVG image based on it. Output only the SVG code.

For subsequent queries:
- Modify the existing SVG code based on the new description
- Add, remove, or alter elements as necessary
- Maintain the overall structure and viewport size
- Return only the modified SVG code

Remember, your response should contain nothing but the SVG code itself."
  end

  private

  def run(input)
    messages = [
      { role: :system, content: system_instructions }
    ] + @messages
    unless input.empty?
      messages += [
        { role: :user, content: input }
      ]
    end

    response = client.chat(parameters: { messages: }.merge(default_params))

    response.dig("choices", 0, "message", "content")
  end
end
