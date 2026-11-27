# Tests get dummy credentials so the real (non-mock) request phase can run.
# .presence: compose sets these to "" when .env doesn't define them.
google_client_id = ENV["GOOGLE_CLIENT_ID"].presence || ("test-client-id" if Rails.env.test?)
google_client_secret = ENV["GOOGLE_CLIENT_SECRET"].presence || ("test-client-secret" if Rails.env.test?)
facebook_app_id = ENV["FACEBOOK_APP_ID"].presence || ("test-app-id" if Rails.env.test?)
facebook_app_secret = ENV["FACEBOOK_APP_SECRET"].presence || ("test-app-secret" if Rails.env.test?)

# Facebook is registered (and routed) only when both its app ID and secret are configured.
facebook_enabled = facebook_app_id.present? && facebook_app_secret.present?
Rails.application.config.x.sign_in_providers = [ "google_oauth2", ("facebook" if facebook_enabled) ].compact

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, google_client_id, google_client_secret, scope: "email,profile"
  provider :facebook, facebook_app_id, facebook_app_secret, scope: "email", info_fields: "name,email", image_size: "normal" if facebook_enabled
end

# Log through Rails (log/test.log in tests) instead of OmniAuth's own stdout logger.
OmniAuth.config.logger = Rails.logger

# Redirect to /auth/failure in development too, instead of raising.
OmniAuth.config.failure_raise_out_environments = []

# OmniAuth builds the callback URL it sends to the provider from the request's
# Host header, which can be forged. Only accept the hosts this app runs on.
OmniAuth.config.allowed_hosts =
  if Rails.env.production?
    [ ENV.fetch("APP_HOST", "bap.fly.dev") ]
  else
    [ "localhost", "127.0.0.1", "www.example.com" ] # www.example.com is the integration test host
  end
