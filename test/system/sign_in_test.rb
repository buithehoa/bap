require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  # The home page's sign in / sign out block is temporarily commented out,
  # so this goes to the sign-in page directly.
  test "user signs in and lands on the home page" do
    visit new_session_path

    fill_in "email_address", with: users(:one).email_address
    fill_in "password", with: "password"
    click_on "Sign in"

    assert_current_path root_path
    assert_selector "h1", text: "Tập Đều Như Bắp"
  end
end
