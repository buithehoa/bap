module ApplicationHelper
  # Facebook Login is offered only when FACEBOOK_APP_ID is set (see config/initializers/omniauth.rb).
  def facebook_sign_in_enabled?
    Rails.configuration.x.sign_in_providers.include?("facebook")
  end
end
