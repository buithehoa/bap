require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "signed out visitors are sent home to sign in" do
    get dashboard_path
    assert_redirected_to root_path
    assert_equal "Sign in to continue.", flash[:alert]
  end

  test "shows the google user's photo, name and email" do
    sign_in_as users(:one)
    get dashboard_path
    assert_response :success
    assert_select "img#avatar[src=?]", users(:one).image_url
    assert_select "#account-name", "User One"
    assert_select "#account-email", "Signed in as one@example.com"
    assert_select "form[action=?] input[name=_method][value=delete]", session_path
    assert_select "form[action=?] button", session_path, text: "Sign out"
  end

  test "shows the provider when a facebook user has no email" do
    sign_in_as users(:facebook_no_email)
    get dashboard_path
    assert_select "#account-email", "Signed in with Facebook"
  end

  test "renders without a photo or name for users who have none" do
    sign_in_as users(:two)
    get dashboard_path
    assert_select "img#avatar", count: 0
    assert_select "#account-name", count: 0
    assert_select "#account-email", "Signed in as two@example.com"
  end
end
