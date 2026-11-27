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

  test "signed out visitors see the Sign in with Google button" do
    get root_path
    assert_select "form[action=?][method=post][data-turbo=false] button", "/auth/google_oauth2", text: "Sign in with Google"
    assert_select "a[href=?]", dashboard_path, count: 0
  end

  test "signed out visitors see the Continue with Facebook button" do
    get root_path
    assert_select "form[action=?][method=post][data-turbo=false] button", "/auth/facebook", text: "Continue with Facebook"
  end

  test "the facebook button is hidden when facebook isn't configured" do
    original = Rails.configuration.x.sign_in_providers
    Rails.configuration.x.sign_in_providers = %w[google_oauth2]
    get root_path
    assert_select "form[action=?]", "/auth/facebook", count: 0
    assert_select "form[action=?]", "/auth/google_oauth2"
  ensure
    Rails.configuration.x.sign_in_providers = original
  end

  test "signed in visitors see a link to the dashboard instead" do
    sign_in_as users(:one)
    get root_path
    assert_select "a[href=?]", dashboard_path, text: "Go to dashboard"
    assert_select "form[action=?]", "/auth/google_oauth2", count: 0
    assert_select "form[action=?]", "/auth/facebook", count: 0
  end

  test "shows the sign in alert after a protected page redirect" do
    get dashboard_path
    follow_redirect!
    assert_select "#alert[role=alert]", "Sign in to continue."
  end

  test "links to the privacy policy" do
    get root_path
    assert_select "a[href=?]", privacy_path
  end
end
