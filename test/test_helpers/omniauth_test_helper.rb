# Fakes Google's OmniAuth response. The hash mirrors omniauth-google-oauth2
# 1.2.3: info.email is only set when Google reports the email as verified.
module OmniauthTestHelper
  def mock_google_auth(uid:, email:, verified: true)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: (verified ? email : nil), unverified_email: email, email_verified: verified }
    )
  end

  def reset_google_auth
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end
end

OmniAuth.config.test_mode = true

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include OmniauthTestHelper
  teardown { reset_google_auth }
end

ActiveSupport.on_load(:action_dispatch_system_test_case) do
  include OmniauthTestHelper
  teardown { reset_google_auth }
end
