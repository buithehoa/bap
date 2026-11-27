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

  test "privacy policy covers facebook sign-in, name and photo" do
    get privacy_path
    assert_select "section[lang=en]", text: /Facebook/
    assert_select "section[lang=en]", text: /your name/
    assert_select "section[lang=en]", text: /ask for your name/, count: 0
    assert_select "section[lang=en]", text: /profile photo/
    assert_select "section[lang=vi]", text: /Facebook/
  end

  test "deletion instructions have stable anchors for Meta" do
    get privacy_path
    assert_select "section[lang=en] h2#delete", "Deleting your data"
    assert_select "section[lang=vi] h2#xoa", "Xóa dữ liệu của bạn"
    assert_select "section[lang=en]", text: /separate accounts/
    assert_select "section[lang=en]", text: /Apps and websites/
    assert_select "section[lang=vi]", text: /Ứng dụng và trang web/
  end
end
