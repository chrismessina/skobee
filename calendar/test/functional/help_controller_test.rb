require File.dirname(__FILE__) + '/../test_helper'
require 'help_controller'

# Re-raise errors caught by the controller.
class HelpController; def rescue_action(e) raise e end; end

class HelpControllerTest < Test::Unit::TestCase
  def setup
    @controller = HelpController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_help
    get :index
    assert_success
    assert_valid_markup

    get :adding_emails
    assert_success
    assert_valid_markup

    get :changing_plans
    assert_success
    assert_valid_markup

    get :email
    assert_success
    assert_valid_markup

    get :making_plans
    assert_success
    assert_valid_markup

    get :notification_settings
    assert_success
    assert_valid_markup

    get :people
    assert_success
    assert_valid_markup

    get :places
    assert_success
    assert_valid_markup

    get :profile
    assert_success
    assert_valid_markup

    get :public_private
    assert_success
    assert_valid_markup

    get :your_account
    assert_success
    assert_valid_markup

    post :navigate, :change_section => 'planners'
    assert_redirected_to "help/planners"

  end
end
