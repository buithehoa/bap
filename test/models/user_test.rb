require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "from_google! creates a user keyed on the google uid" do
    user = assert_difference("User.count", 1) { User.from_google!(uid: "google-uid-new", email: " New@Example.com ") }
    assert_equal "google-uid-new", user.google_uid
    assert_equal "new@example.com", user.email_address
  end

  test "from_google! finds an existing user by uid and refreshes the email" do
    assert_no_difference("User.count") do
      assert_equal users(:one), User.from_google!(uid: "google-uid-one", email: "changed@example.com")
    end
    assert_equal "changed@example.com", users(:one).reload.email_address
  end

  test "from_google! allows an email another user already holds" do
    user = assert_difference("User.count", 1) { User.from_google!(uid: "google-uid-new", email: users(:one).email_address) }
    assert_equal users(:one).email_address, user.email_address
  end

  test "requires a google uid" do
    user = User.new(email_address: "x@example.com")
    assert_not user.valid?
    assert_includes user.errors[:google_uid], "can't be blank"
  end
end
