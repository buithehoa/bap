Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"], scope: "email"
end

# Redirect to /auth/failure in development too, instead of raising.
OmniAuth.config.failure_raise_out_environments = []
