require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to root_path
    assert_empty cookies[:session_id]
  end

  test "google callback creates a user and signs in" do
    mock_google_auth(uid: "google-uid-new", email: "new@example.com")
    assert_difference("User.count", 1) { get "/auth/google_oauth2/callback" }
    assert_redirected_to dashboard_url
    assert cookies[:session_id].present?
  end

  test "google callback signs in an existing user and refreshes the email" do
    mock_google_auth(uid: "google-uid-one", email: "changed@example.com")
    assert_no_difference("User.count") { get "/auth/google_oauth2/callback" }
    assert_redirected_to dashboard_url
    assert_equal "changed@example.com", users(:one).reload.email_address
  end

  test "google callback signs in a new account whose email another user holds" do
    mock_google_auth(uid: "google-uid-new", email: users(:one).email_address)
    assert_difference("User.count", 1) { get "/auth/google_oauth2/callback" }
    assert_redirected_to dashboard_url
  end

  test "google callback rejects an unverified email" do
    mock_google_auth(uid: "google-uid-new", email: "new@example.com", verified: false)
    assert_no_difference("User.count") { get "/auth/google_oauth2/callback" }
    assert_redirected_to root_path
    assert_equal "Your Google account's email isn't verified.", flash[:alert]
    assert cookies[:session_id].blank?
  end

  test "cancelling on google shows an alert and does not sign in" do
    OmniAuth.config.mock_auth[:google_oauth2] = :access_denied
    get "/auth/google_oauth2/callback"
    follow_redirect! # OmniAuth sends failures to /auth/failure?message=access_denied&strategy=google_oauth2
    assert_redirected_to root_path
    assert_equal "Google sign-in didn't complete. Try again.", flash[:alert]
    assert cookies[:session_id].blank?
  end

  test "facebook callback creates a user without an email and signs in" do
    mock_facebook_auth(uid: "fb-new", name: "New FB")
    assert_difference("User.count", 1) { get "/auth/facebook/callback" }
    assert_redirected_to dashboard_url
    assert cookies[:session_id].present?
  end

  test "facebook callback signs in the existing facebook user" do
    mock_facebook_auth(uid: "fb-uid-one", name: "Same Person")
    assert_no_difference("User.count") { get "/auth/facebook/callback" }
    assert_redirected_to dashboard_url
    assert cookies[:session_id].present?
  end

  test "google callback stores the name and photo" do
    mock_google_auth(uid: "google-uid-new", email: "new@example.com", name: "New Person", image: "https://example.com/p.jpg")
    get "/auth/google_oauth2/callback"
    user = User.find_by!(provider: "google_oauth2", uid: "google-uid-new")
    assert_equal "New Person", user.name
    assert_equal "https://example.com/p.jpg", user.image_url
  end

  test "cancelling on facebook names facebook in the alert" do
    OmniAuth.config.mock_auth[:facebook] = :access_denied
    get "/auth/facebook/callback"
    follow_redirect!
    assert_redirected_to root_path
    assert_equal "Facebook sign-in didn't complete. Try again.", flash[:alert]
    assert cookies[:session_id].blank?
  end

  test "failure without a known strategy shows a generic alert" do
    get "/auth/failure", params: { message: "x", strategy: "twitter" }
    assert_redirected_to root_path
    assert_equal "Sign-in didn't complete. Try again.", flash[:alert]

    get "/auth/failure", params: { message: "x" }
    assert_redirected_to root_path
    assert_equal "Sign-in didn't complete. Try again.", flash[:alert]
  end

  test "starting facebook sign-in with GET is not allowed" do
    get "/auth/facebook"
    assert_response :not_found
  end

  test "an unknown provider callback is not routed" do
    get "/auth/twitter/callback"
    assert_response :not_found
  end

  test "real facebook request phase sends the browser to Facebook with this host's callback" do
    OmniAuth.config.test_mode = false
    post "/auth/facebook"
    assert_match %r{\Ahttps://www\.facebook\.com/v24\.0/dialog/oauth\?}, response.location
    assert_includes response.location, "redirect_uri=#{CGI.escape("http://www.example.com/auth/facebook/callback")}"
  ensure
    OmniAuth.config.test_mode = true
  end

  test "starting google sign-in with GET is not allowed" do
    get "/auth/google_oauth2"
    assert_response :not_found
  end

  test "real request phase sends the browser to Google with this host's callback" do
    OmniAuth.config.test_mode = false
    post "/auth/google_oauth2"
    assert_match %r{\Ahttps://accounts\.google\.com/o/oauth2/auth\?}, response.location
    assert_match(/scope=email(\+|%20)profile/, response.location)
    assert_includes response.location, "redirect_uri=#{CGI.escape("http://www.example.com/auth/google_oauth2/callback")}"
  ensure
    OmniAuth.config.test_mode = true
  end

  test "real request phase refuses a forged host" do
    OmniAuth.config.test_mode = false
    host! "evil.example"
    post "/auth/google_oauth2"
    assert_match %r{/auth/failure\?message=invalid_host}, response.location
  ensure
    OmniAuth.config.test_mode = true
  end

  test "after sign-in returns to the page originally requested" do
    get dashboard_path(from: "x")
    assert_redirected_to root_path
    mock_google_auth(uid: "google-uid-one", email: users(:one).email_address)
    get "/auth/google_oauth2/callback"
    assert_redirected_to dashboard_url(from: "x")
  end

  test "after sign-in returns to a page first requested with HEAD" do
    head dashboard_path(from: "head")
    mock_google_auth(uid: "google-uid-one", email: users(:one).email_address)
    get "/auth/google_oauth2/callback"
    assert_redirected_to dashboard_url(from: "head")
  end

  test "signing out from a stale tab, then signing in, lands on the dashboard" do
    sign_in_as users(:one)
    delete session_path
    delete session_path # second tab, already signed out
    mock_google_auth(uid: "google-uid-one", email: users(:one).email_address)
    get "/auth/google_oauth2/callback"
    assert_redirected_to dashboard_url
  end

  test "rate limited callback redirects home" do
    mock_google_auth(uid: "google-uid-one", email: users(:one).email_address)
    # The test env cache is a null store, so make it report an 11th attempt.
    # (Minitest 6 dropped Object#stub.)
    store = SessionsController.cache_store
    store.define_singleton_method(:increment) { |*| 11 }
    get "/auth/google_oauth2/callback"
    assert_redirected_to root_path
    assert_equal "Try again later.", flash[:alert]
  ensure
    store&.singleton_class&.remove_method(:increment)
  end
end
