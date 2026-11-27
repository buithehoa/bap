require "test_helper"

class UserTest < ActiveSupport::TestCase
  def auth_for(provider:, uid:, **info)
    OmniAuth::AuthHash.new(provider: provider, uid: uid, info: info)
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "from_omniauth! creates a google user with name, email and photo" do
    auth = auth_for(provider: "google_oauth2", uid: "g-new", name: "New Person", email: " New@Example.com ", image: "https://example.com/p.jpg")
    user = assert_difference("User.count", 1) { User.from_omniauth!(auth) }
    assert_equal "google_oauth2", user.provider
    assert_equal "g-new", user.uid
    assert_equal "New Person", user.name
    assert_equal "new@example.com", user.email_address
    assert_equal "https://example.com/p.jpg", user.image_url
  end

  test "from_omniauth! creates a facebook user without an email" do
    auth = auth_for(provider: "facebook", uid: "fb-new", name: "No Email")
    user = assert_difference("User.count", 1) { User.from_omniauth!(auth) }
    assert user.persisted?
    assert_nil user.email_address
  end

  test "from_omniauth! finds an existing user by provider and uid and refreshes the profile" do
    auth = auth_for(provider: "google_oauth2", uid: "google-uid-one", name: "Changed Name", email: "changed@example.com")
    assert_no_difference("User.count") do
      assert_equal users(:one), User.from_omniauth!(auth)
    end
    users(:one).reload
    assert_equal "Changed Name", users(:one).name
    assert_equal "changed@example.com", users(:one).email_address
  end

  test "from_omniauth! clears details the provider no longer sends" do
    auth = auth_for(provider: "facebook", uid: "fb-uid-one", name: "Facebook Person")
    User.from_omniauth!(auth)
    assert_nil users(:facebook_no_email).reload.image_url
  end

  test "from_omniauth! clears the email when facebook stops sending one" do
    User.from_omniauth!(auth_for(provider: "facebook", uid: "fb-uid-one", name: "Facebook Person", email: "fb@example.com"))
    assert_equal "fb@example.com", users(:facebook_no_email).reload.email_address
    User.from_omniauth!(auth_for(provider: "facebook", uid: "fb-uid-one", name: "Facebook Person"))
    assert_nil users(:facebook_no_email).reload.email_address
  end

  test "the same uid from two providers makes two accounts" do
    auth = auth_for(provider: "facebook", uid: "google-uid-one", name: "Other")
    user = assert_difference("User.count", 1) { User.from_omniauth!(auth) }
    assert_not_equal users(:one), user
  end

  test "from_omniauth! allows an email another user already holds" do
    auth = auth_for(provider: "google_oauth2", uid: "g-new", email: users(:one).email_address)
    user = assert_difference("User.count", 1) { User.from_omniauth!(auth) }
    assert_equal users(:one).email_address, user.email_address
  end

  test "provider_name is the display name" do
    assert_equal "Facebook", users(:facebook_no_email).provider_name
    assert_equal "Google", users(:one).provider_name
  end

  test "requires a known provider and a uid" do
    user = User.new(provider: "twitter", uid: "x")
    assert_not user.valid?
    assert user.errors[:provider].any?

    user = User.new(provider: "facebook")
    assert_not user.valid?
    assert_includes user.errors[:uid], "can't be blank"
  end
end
