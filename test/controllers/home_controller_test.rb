require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root is public and offers sign in" do
    get root_path

    assert_response :success
    assert_select "h1", "Bap"
    assert_select "a[href=?]", new_session_path
  end

  test "root greets a signed-in user and offers sign out" do
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_select "p", /one@example\.com/
    assert_select "form[action=?] button", session_path, "Sign out"
  end
end
