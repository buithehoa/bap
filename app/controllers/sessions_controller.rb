class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ create failure ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to root_path, alert: "Try again later." }

  # Google and Facebook redirect here after sign-in. omniauth-google-oauth2
  # only sets info.email when Google reports the address as verified.
  # Facebook accounts may have no email at all, so only Google is held to it.
  def create
    auth = request.env["omniauth.auth"]

    if auth.provider == "google_oauth2" && auth.info.email.blank?
      redirect_to root_path, alert: "Your Google account's email isn't verified."
    else
      start_new_session_for User.from_omniauth!(auth)
      redirect_to after_authentication_url
    end
  end

  def failure
    provider_name = User::PROVIDER_NAMES[params[:strategy]]
    alert = provider_name ? "#{provider_name} sign-in didn't complete. Try again." : "Sign-in didn't complete. Try again."
    redirect_to root_path, alert: alert
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other
  end
end
