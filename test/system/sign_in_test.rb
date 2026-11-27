require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "user signs in with Google, sees their email, and signs out" do
    mock_google_auth(uid: users(:one).uid, email: users(:one).email_address)
    visit root_path
    click_on "Sign in with Google"
    assert_current_path dashboard_path
    assert_text "Signed in as one@example.com"
    click_on "Sign out"
    assert_current_path root_path
    assert_button "Sign in with Google"
  end

  test "user signs in with Facebook without an email" do
    mock_facebook_auth(uid: "fb-sys", name: "Sys FB")
    visit root_path
    click_on "Continue with Facebook"
    assert_current_path dashboard_path
    assert_text "Sys FB"
    assert_text "Signed in with Facebook"
  end
end
