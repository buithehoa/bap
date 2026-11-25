require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "user signs in with Google, sees their email, and signs out" do
    mock_google_auth(uid: users(:one).google_uid, email: users(:one).email_address)
    visit root_path
    click_on "Sign in with Google"
    assert_current_path dashboard_path
    assert_text "Signed in as one@example.com"
    click_on "Sign out"
    assert_current_path root_path
    assert_button "Sign in with Google"
  end
end
