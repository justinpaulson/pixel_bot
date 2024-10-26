class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    email = params.require(:email_address).downcase
    password = params.require(:password)

    user = User.find_by(email_address: email)

    if user
      if user = User.authenticate_by(email_address: email, password: password)
        # Existing user - attempt authentication
        start_new_session_for user
        redirect_to after_authentication_url
      else
        redirect_to new_session_url, alert: "Invalid password."
      end
    else
      # New user - create account
      user = User.new(
        email_address: email,
        password: password,
        password_confirmation: password
      )

      if user.save
        start_new_session_for user
        redirect_to after_authentication_url, notice: "Account created successfully!"
      else
        redirect_to new_session_url, alert: user.errors.full_messages.to_sentence
      end
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_url
  end

  private

  # Add protection against timing attacks by using secure_compare
  def authenticate_user(user, password)
    return false unless user
    ActiveSupport::SecurityUtils.secure_compare(
      user.authenticate_by(password: password),
      true
    )
  end
end
