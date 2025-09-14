class DrawingBot
  def initialize(round:)
    @round = round
    @messages = @round.messages.map do |message|
      [
        { role: :user, content: message.content },
        { role: :assistant, content: message.image_content }
      ]
    end.flatten
  end

  def name
    "Pixel Bot"
  end

  def description
    "A bot that draws SVGs."
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

  def run(input)
    # Create a new chat instance with the GPT-4o model
    chat = RubyLLM.chat(model: "gpt-4o")

    # Set system instructions
    chat.with_instructions(system_instructions)

    # Add previous messages to maintain conversation context
    @messages.each do |message|
      chat.add_message(message)
    end

    # Add the new user input if provided
    unless input.empty?
      chat.add_message(role: :user, content: input)
    end

    # Get the response from the model
    response = chat.complete

    # Return the content of the response
    response.content
  end

end