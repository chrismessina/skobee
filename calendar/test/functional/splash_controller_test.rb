require File.dirname(__FILE__) + '/../test_helper'
require 'splash_controller'

# Re-raise errors caught by the controller.
class SplashController; def rescue_action(e) raise e end; end

class SplashControllerTest < Test::Unit::TestCase
  def setup
    @controller = SplashController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_xhtml
    get :index
    assert_success
    assert_valid_markup

    get :tour
    assert_success
    assert_valid_markup

    get :tour_plans
    assert_success
    assert_valid_markup

    get :tour_planner
    assert_success
    assert_valid_markup

    get :email_tour
    assert_success
    assert_valid_markup

    get :email_howto
    assert_success
    assert_valid_markup

    #MGS- now login and you should only be able to see some of these pages...the email ones
    login
    get :index
    assert_redirect

    get :tour
    assert_redirect

    get :tour_plans
    assert_redirect

    get :tour_planner
    assert_redirect

    get :email_tour
    assert_success

    get :email_howto
    assert_success
  end
end
