class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ create failure ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to root_path, alert: "Try again later." }

  # Google redirects here after sign-in. omniauth-google-oauth2 only sets
  # info.email when Google reports the address as verified.
  def create
    auth = request.env["omniauth.auth"]

    if auth.info.email.blank?
      redirect_to root_path, alert: "Your Google account's email isn't verified."
    else
      start_new_session_for User.from_google!(uid: auth.uid, email: auth.info.email)
      redirect_to after_authentication_url
    end
  end

  def failure
    redirect_to root_path, alert: "Google sign-in didn't complete. Try again."
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other
  end
end
