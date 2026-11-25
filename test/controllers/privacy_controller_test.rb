require "test_helper"

class PrivacyControllerTest < ActionDispatch::IntegrationTest
  test "privacy policy is public and in English and Vietnamese" do
    get privacy_path
    assert_response :success
    assert_select "section[lang=en] h1", "Privacy Policy"
    assert_select "section[lang=vi] h1", "Chính sách quyền riêng tư"
  end

  test "privacy policy lists the data bap stores and a contact for deletion" do
    get privacy_path
    assert_select "section[lang=en]", text: /email address/
    assert_select "section[lang=en]", text: /IP address/
    assert_select "a[href=?]", "mailto:buithehoa@gmail.com", minimum: 2
  end
end
