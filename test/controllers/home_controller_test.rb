require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root is public and shows the centered heading" do
    get root_path

    assert_response :success
    assert_select "main.items-center.justify-center h1.text-center", "Tập Đều Như Bắp"
  end

  test "root uses the corn photo as a full-page background" do
    get root_path

    assert_select "[data-home-background].fixed.inset-0.bg-cover.bg-center[style*=?]", "/assets/home-corn-"
  end

  test "root hides the sign in / sign out block while it is commented out" do
    get root_path
    assert_select "a[href=?]", new_session_path, count: 0

    sign_in_as users(:one)
    get root_path
    assert_select "form[action=?]", session_path, count: 0
  end
end
