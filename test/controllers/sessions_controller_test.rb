require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to root_path
    assert_empty cookies[:session_id]
  end
end
