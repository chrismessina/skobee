require File.dirname(__FILE__) + '/../test_helper'
require 'feedbacks_controller'

# Re-raise errors caught by the controller.
class FeedbacksController; def rescue_action(e) raise e end; end

#########################################################################################
#MES- Simple tests that only rely on the users and emails tables
#########################################################################################

class FeedbacksControllerTest_Simple < Test::Unit::TestCase
  fixtures :users, :emails

  def setup
    @controller = FeedbacksController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end
  

  def test_index
    login users(:security_token_user)

    get :index
    assert_response :success
    assert_template 'list'
  end

  def test_list
    login users(:security_token_user)

    get :list

    assert_response :success
    assert_template 'list'

    assert_not_nil assigns(:feedbacks)
  end

  def test_require_login
    #MES- All pages should require login

    #MES- Make sure we're not logged in
    logout

    get :index
    assert_redirect_to_login

    get :list
    assert_redirect_to_login

    get :show, :id => 1
    assert_redirect_to_login

    get :new
    assert_redirect_to_login

    post :create, :feedback => {}
    assert_redirect_to_login

    get :edit, :id => 1
    assert_redirect_to_login

    post :update, :id => 1
    assert_redirect_to_login

    post :destroy, :id => 1
    assert_redirect_to_login
  end
end

#########################################################################################
#MES- Tests that rely on users and feedbacks
#########################################################################################

class FeedbacksControllerTest_fb < Test::Unit::TestCase
  fixtures :feedbacks, :users, :emails

  def setup
    @controller = FeedbacksController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_show
    login users(:security_token_user)

    get :show, :id => 1

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:feedback)
    assert assigns(:feedback).valid?
  end

  def test_new
    login users(:security_token_user)

    get :new

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:feedback)
  end

  def test_create
    login users(:security_token_user)

    num_feedbacks = Feedback.count

    post :create, :feedback => {}

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal num_feedbacks + 1, Feedback.count
  end

  def test_edit
    login users(:security_token_user)

    get :edit, :id => 1

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:feedback)
    assert assigns(:feedback).valid?
  end

  def test_update
    login users(:security_token_user)

    post :update, :id => 1
    assert_response :redirect
    assert_redirected_to :action => 'show', :id => 1
  end

  def test_destroy
    login users(:security_token_user)

    assert_not_nil Feedback.find(1)

    post :destroy, :id => 1
    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_raise(ActiveRecord::RecordNotFound) {
      Feedback.find(1)
    }
  end
end

#########################################################################################
#MES- Complicated tests that rely on various fixtures
#########################################################################################

class FeedbacksControllerTest_complex < Test::Unit::TestCase
  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false
  
  fixtures :feedbacks, :users, :planners, :emails, :comments, :places, :plans

  def setup
    @controller = FeedbacksController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_security
    #MES- Test that a "normal" user (i.e. non Admin) gets redirected
    # when going to any page in the feedback stuff

    login
    cal_ctrl = PlannersController.new

    #MES- View the user's planner, to have something to redirect back to
    cal_id = users(:bob).planner.id
    get_to_controller(cal_ctrl, :show, { :id => cal_id })

    get :list
    assert_redirect

    get_to_controller(cal_ctrl, :show, { :id => cal_id })
    get :index
    #MES- The location of the redirect is NOT reliable.  Somehow,
    # using get_to_controller is messing up the redirect URL.  The
    # redirect works correctly when the UI is used, but the test gets
    # redirected to the url in feedbacks, instead of the url in
    # planners.  I spent a lot of time on this with no success.
    # The problem is that the @request.request_uri variable (which is stored
    # as the location to return to) is not being reliably set by get_to_controller.
    # It ends up having the previous value, so the redirect goes to the wrong place.
    assert_redirect

    get_to_controller(cal_ctrl, :show, { :id => cal_id })
    get :show, :id => 1
    assert_redirect

    get_to_controller(cal_ctrl, :show, { :id => cal_id })
    get :new
    assert_redirect

    get_to_controller(cal_ctrl, :show, { :id => cal_id })
    post :create, :feedback => {}
    assert_redirect

    get_to_controller(cal_ctrl, :show, { :id => cal_id })
    get :edit, :id => 1
    assert_redirect

    get_to_controller(cal_ctrl, :show, { :id => cal_id })
    post :update, :id => 1
    assert_redirect

    get_to_controller(cal_ctrl, :show, { :id => cal_id })
    post :destroy, :id => 1
    assert_redirect
  end

  def test_comment_inappropriate
    login

    get :comment_inappropriate_ajax, :comment_id => "1", :place_id => "1", :request_url => "/places/show/1?cal_id=1"
    assert_success
    assert_not_nil assigns(:feedback)
    assert assigns(:feedback).url == "/places/show/1?cal_id=1"
    assert assigns(:feedback).user_id == @request.session['user_id']
    assert assigns(:feedback).feedback_type == Feedback::FEEDBACK_TYPE_INAPPROPRIATE
    assert assigns(:feedback).stage == Feedback::FEEDBACK_STAGE_NEW

    get :comment_inappropriate_ajax, :comment_id => "1", :plan_id => "1", :request_url => "/plans/show/1?cal_id=1"
    assert_success
    assert_success
    assert_not_nil assigns(:feedback)
    assert assigns(:feedback).url == "/plans/show/1?cal_id=1"
    assert assigns(:feedback).user_id == @request.session['user_id']
    assert assigns(:feedback).feedback_type == Feedback::FEEDBACK_TYPE_INAPPROPRIATE
    assert assigns(:feedback).stage == Feedback::FEEDBACK_STAGE_NEW
  end

end
