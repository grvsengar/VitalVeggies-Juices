require "test_helper"

class ManagerMarketingStudioTest < ActionDispatch::IntegrationTest
  test "manager sees article picker when no article id is provided" do
    post login_path, params: { email: users(:manager).email, password: "password123" }
    follow_redirect!

    get manager_marketing_studio_path

    assert_response :success
    assert_match "Marketing Studio", response.body
    assert_match articles(:one).title, response.body
    assert_match articles(:two).title, response.body
  end

  test "manager can open studio for a specific article" do
    post login_path, params: { email: users(:manager).email, password: "password123" }
    follow_redirect!

    get manager_marketing_studio_path(article_id: articles(:one).id)

    assert_response :success
    assert_match "Pro Studio", response.body
    assert_match articles(:one).title, response.body
  end
end
