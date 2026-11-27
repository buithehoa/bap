# Fakes Google's and Facebook's OmniAuth responses. The hash mirrors omniauth-google-oauth2
# 1.2.3: info.email is only set when Google reports the email as verified.
module OmniauthTestHelper
  def mock_google_auth(uid:, email:, verified: true, name: nil, image: nil)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: (verified ? email : nil), unverified_email: email, email_verified: verified, name: name, image: image }
    )
  end

  # Facebook only sends the fields it has; omniauth-facebook leaves out the rest.
  def mock_facebook_auth(uid:, name: nil, email: nil, image: nil)
    OmniAuth.config.mock_auth[:facebook] = OmniAuth::AuthHash.new(
      provider: "facebook",
      uid: uid,
      info: { name: name, email: email, image: image }.compact
    )
  end

  def reset_omniauth_mocks
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.mock_auth[:facebook] = nil
  end
end

OmniAuth.config.test_mode = true

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include OmniauthTestHelper
  teardown { reset_omniauth_mocks }
end

ActiveSupport.on_load(:action_dispatch_system_test_case) do
  include OmniauthTestHelper
  teardown { reset_omniauth_mocks }
end
