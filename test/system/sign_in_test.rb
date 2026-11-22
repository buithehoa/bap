require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "user signs in from the home page and signs out" do
    visit root_path
    click_on "Sign in"

    fill_in "email_address", with: users(:one).email_address
    fill_in "password", with: "password"
    click_on "Sign in"

    assert_text "Signed in as one@example.com"

    click_on "Sign out"
    assert_current_path new_session_path
  end
end
