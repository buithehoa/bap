require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "signed out visitors are sent home to sign in" do
    get dashboard_path
    assert_redirected_to root_path
    assert_equal "Sign in to continue.", flash[:alert]
  end

  test "shows the signed-in email and a sign out button" do
    sign_in_as users(:one)
    get dashboard_path
    assert_response :success
    assert_select "p", text: "Signed in as one@example.com"
    assert_select "form[action=?] input[name=_method][value=delete]", session_path
    assert_select "form[action=?] button", session_path, text: "Sign out"
  end
end
