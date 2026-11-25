# Tests get dummy credentials so the real (non-mock) request phase can run.
# .presence: compose sets these to "" when .env doesn't define them.
google_client_id = ENV["GOOGLE_CLIENT_ID"].presence || ("test-client-id" if Rails.env.test?)
google_client_secret = ENV["GOOGLE_CLIENT_SECRET"].presence || ("test-client-secret" if Rails.env.test?)

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, google_client_id, google_client_secret, scope: "email"
end

# Redirect to /auth/failure in development too, instead of raising.
OmniAuth.config.failure_raise_out_environments = []

# OmniAuth builds the callback URL it sends to Google from the request's
# Host header, which can be forged. Only accept the hosts this app runs on.
OmniAuth.config.allowed_hosts =
  if Rails.env.production?
    [ ENV.fetch("APP_HOST", "bap.fly.dev") ]
  else
    [ "localhost", "127.0.0.1", "www.example.com" ] # www.example.com is the integration test host
  end
