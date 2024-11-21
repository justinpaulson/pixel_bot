# Pixel

Pixel is a drawing game where players take turns drawing and guessing words. The game is played in rounds, with each round consisting of a single player sending prompts to an LLM to generate images for a particular word while the other players guess the word.

## Ruby Version

This project uses Ruby version 3.2.2. Ensure you have this version installed before proceeding.

## System Dependencies

- Ruby 3.2.2
- Rails 8.0.0
- SQLite3
- Node.js and Yarn
- Docker (for deployment)

## Configuration

1. Clone the repository:
    ```sh
    git clone https://github.com/yourusername/pixel_bot.git
    cd pixel_bot
    ```

2. Install dependencies:
    ```sh
    bundle install
    ```

3. Set up environment variables:
    Create a `.env` file in the root directory and add the necessary environment variables:
    ```env
    RAILS_MASTER_KEY=your_master_key
    ```

4. You will need an access token for Open AI for the LLM calls, you can add it using rails credentials. Use the following the edit the rails credentials with VS Code.
    ```sh
    EDITOR="code --wait" rails credentials:edit
    ```

    add the following entry with your OpenAI access token:

    ```
    openai_access_token: <YOUR_TOKEN_HERE>
    ```

## Database Creation

Set up the database:
    ```sh
    bin/rails db:setup
    ```

## Deployment

This project is set up to deploy using Kamal 2. It deploys when the main branch is pushed to GitHub.

## License

This project is licensed under the MIT License.
