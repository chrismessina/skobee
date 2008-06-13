require File.dirname(__FILE__) + '/../test_helper'
require 'plans_controller'

# Re-raise errors caught by the controller.
class PlansController; def rescue_action(e) raise e end; end

#MES- These tests are kinda poorly organized right now.  Since there are so many,
# and this suite runs so slowly, I tried to break each test out to a class
# that includes only the minimal fixtures necessary.  But this makes them
# pretty hard to read.  So we get some performance boost, but at the cost of
# some readability.  Sorry!

class PlansControllerTest_1 < Test::Unit::TestCase
  fixtures :users, :planners, :emails

  def setup
    @controller = PlansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  def test_time_changes
    login users(:bob)
    #MGS- create a plan and make some changes about the time of the plan
    post :create, {:plan => {:name => "revert test plan"}, :dateperiod => Plan::DATE_DESCRIPTION_FUTURE, :timeperiod => Plan::TIME_DESCRIPTION_ALL_DAY}
    plan = assigns(:plan)
    assert_not_nil plan

    get :show, :id => plan.id, :cal_id => planners(:first_planner).id

    #MGS- now change the time to TODAY, DINNER
    post :edit_when, :id => plan.id, :dateperiod => Plan::DATE_DESCRIPTION_TODAY, :timeperiod => Plan::TIME_DESCRIPTION_DINNER, :comment_tb => "Let's go to dinner today"
    today_dinner_change = assigns(:plan).plan_changes.select { |pc| PlanChange::CHANGE_TYPE_TIME == pc.change_type}.max{ |a, b| a.id <=> b.id }
    #MGS- now change the time to TOMORROW, LUNCH
    post :edit_when, :id => plan.id, :dateperiod => Plan::DATE_DESCRIPTION_TOMORROW, :timeperiod => Plan::TIME_DESCRIPTION_LUNCH, :comment_tb => "Let's go to lunch tomorrow"
    tomorrow_lunch_change = assigns(:plan).plan_changes.select { |pc| PlanChange::CHANGE_TYPE_TIME == pc.change_type}.max{ |a, b| a.id <=> b.id }
    #MGS- now change the time to SOME DAY NEXT WEEK, BREAKFAST
    post :edit_when, :id => plan.id, :dateperiod => Plan::DATE_DESCRIPTION_NEXT_WEEK, :timeperiod => Plan::TIME_DESCRIPTION_BREAKFAST, :comment_tb => "Let's go to breakfast sometime next week"
    sdnw_breakfast_change = assigns(:plan).plan_changes.select { |pc| PlanChange::CHANGE_TYPE_TIME == pc.change_type}.max{ |a, b| a.id <=> b.id }

    assert today_dinner_change.comment.match("Let's go to dinner today")
    assert tomorrow_lunch_change.comment.match("Let's go to lunch tomorrow")
    assert sdnw_breakfast_change.comment.match("Let's go to breakfast sometime next week")

    #MGS- reload the plan
    get :show, :id => plan.id, :cal_id => planners(:first_planner)
    plan = assigns(:plan)
    #MGS- check that the right revert links are in the html
    assert_tag :tag => 'a', :content => 'Switch back to this plan', :attributes => { :href => "/plans/revert/#{plan.id}?change_id=#{today_dinner_change.id}" }
    assert_tag :tag => 'a', :content => 'Switch back to this plan', :attributes => { :href => "/plans/revert/#{plan.id}?change_id=#{tomorrow_lunch_change.id}" }
    #this should be the current plan
    assert_no_tag :tag => 'a', :content => 'Switch back to this plan', :attributes => { :href => "/plans/revert/#{plan.id}?change_id=#{sdnw_breakfast_change.id}" }

    #MGS- change the time to tomorrrow
    tomorrow = plan.created_at.getgm + 1.day
    Time.set_now_gmt(tomorrow.year, tomorrow.month, tomorrow.day, tomorrow.hour) do
      #MGS- reload the plan
      get :show, :id => plan.id, :cal_id => planners(:first_planner)
      plan = assigns(:plan)
      #MGS- check that the right revert links are in the html
      #MGS- this first change now is in the past, so a revert link shouldn't be here
      assert_no_tag :tag => 'a', :content => 'Switch back to this plan', :attributes => { :href => "/plans/revert/#{plan.id}?change_id=#{today_dinner_change.id}" }
      assert_tag :tag => 'a', :content => 'Switch back to this plan', :attributes => { :href => "/plans/revert/#{plan.id}?change_id=#{tomorrow_lunch_change.id}" }
      #this should be the current plan
      assert_no_tag :tag => 'a', :content => 'Switch back to this plan', :attributes => { :href => "/plans/revert/#{plan.id}?change_id=#{sdnw_breakfast_change.id}" }
    end

    #MGS- change the time to two days from now
    two_days_from_now = plan.created_at.getgm + 2.day
    Time.set_now_gmt(two_days_from_now.year, two_days_from_now.month, two_days_from_now.day, two_days_from_now.hour) do
      #MGS- reload the plan
      get :show, :id => plan.id, :cal_id => planners(:first_planner)
      plan = assigns(:plan)
      #MGS- check that the right revert links are in the html
      #MGS- no changes, should be revertable
      assert_no_tag :tag => 'a', :content => 'Switch back to this plan', :attributes => { :href => "/plans/revert/#{plan.id}?change_id=#{today_dinner_change.id}" }
      assert_no_tag :tag => 'a', :content => 'Switch back to this plan', :attributes => { :href => "/plans/revert/#{plan.id}?change_id=#{tomorrow_lunch_change.id}" }
      #this should be the current plan
      assert_no_tag :tag => 'a', :content => 'Switch back to this plan', :attributes => { :href => "/plans/revert/#{plan.id}?change_id=#{sdnw_breakfast_change.id}" }
    end

  end
end


class PlansControllerTest_2 < Test::Unit::TestCase
  fixtures :users, :plans, :planners, :planners_plans, :emails

  def setup
    @controller = PlansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  def test_undo_email_plan_creation
    #KS- make sure we're not logged in
    logout

    user = users(:user_with_friends)

    #KS- preconditions: plan 1 exists and the user is allowed to create plans
    #via email
    plan = plans(:first_plan)
    plan_id = plan.id
    assert_not_nil plan
    assert_not_equal 0, user.get_att_value(UserAttribute::ATT_ALLOW_PLAN_CREATION_VIA_EMAIL)

    token = user.generate_security_token

    #KS- delete the plan, turn off plan creation via email
    post :undo_email_plan_creation, :id => plan_id, :user_id => user.id, :token => token, :delete_plan => 'on', :disallow_plan_creation_via_email => 'on'

    #KS- make sure the plan was deleted and the user_att was set
    assert_nil Plan.find(:first, :conditions => "id = #{plan_id}")
    user = users(:user_with_friends, :force)
    assert_equal 0, user.get_att_value(UserAttribute::ATT_ALLOW_PLAN_CREATION_VIA_EMAIL)
  end

  def test_show
    usr = users(:contact_1_of_user)
    login usr

    #MES- Before viewing the plan, the user in question should NOT have been marked as having
    # seen the plan
    pln = plans(:contact_1_of_user_plan)
    assert_nil usr.planner.plans.detect{ |x| x.id == pln.id }.viewed_at

    get :show, :id => pln.id, :cal_id => users(:contact_1_of_user).planner.id
    assert_valid_markup
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:plan)

    #MES- After viewing the plan, the viewed_at should be set to 'now'
    va = usr.planner.plans(true).detect{ |x| x.id == pln.id }.viewed_at
    assert_not_nil va
    assert va.to_time.near?(Time.now_utc)

    #MES- When looking at the plans that are on the planners
    #  of OTHER users, the visibility, and hence the template used,
    #  will depend on security settings for the owner.

    #MES- Look at our own planner
    show_test_helper users(:contact_1_of_user), plans(:contact_1_of_user_plan), planners(:contact_1_of_user_planner).id, 'owner_view'

    #MES- Have someone else look at our planner- user_with_contacts should see the details
    show_test_helper users(:user_with_contacts), plans(:contact_1_of_user_plan), planners(:contact_1_of_user_planner).id, 'all_details'

    #MES- Have someone else look at our planner- contact_2_of_user should see no details
    show_test_helper users(:contact_2_of_user), plans(:contact_1_of_user_plan), planners(:contact_1_of_user_planner).id, 'all_details'

    #MES- For a private planner, friends and strangers should see the availability view
    #MES- Friend
    show_test_helper users(:user_with_friends), plans(:user_with_friends_and_private_cal_plan), planners(:user_with_friends_and_private_cal_planner).id, 'availability'
    #MES- Stranger
    show_test_helper users(:not_a_friend), plans(:user_with_friends_and_private_cal_plan), planners(:user_with_friends_and_private_cal_planner).id, 'availability'

    #MES- If the plan isn't ON the planner we specify, we should get
    #  an error
    assert_raise(RuntimeError) { get :show, :id =>plans(:contact_1_of_user_plan).id, :cal_id => planners(:first_planner).id }

    #MES- If the plan IS on the planner, but is PRIVATE, we should get an error
    pln = plans(:contact_1_of_user_plan)
    pln.security_level = Plan::SECURITY_LEVEL_PRIVATE
    pln.save!
    assert_raise(RuntimeError) { get :show, :id =>pln.id, :cal_id => planners(:contact_1_of_user_planner).id }
  end

  def show_test_helper user, plan, cal_id, expected_subtemplate
    login user
    get :show, :id => plan.id, :cal_id => cal_id
    assert_response :success
    assert_template 'show'
    assert_tag :tag => 'span', :attributes => { :id => expected_subtemplate }
    #MGS- since the html is constantly changing, we don't need to look for the text
    # in a particular tag, but just somewhere on the page
    assert_tag :content => plan.name
    assert_tag :content => plan.description
    assert_valid_markup
  end

  def test_show_not_authenticated
    logout

    usr = users(:contact_1_of_user)
    pln = plans(:contact_1_of_user_plan)
    plnr = usr.planner
    get :show, :id => pln.id, :cal_id => plnr.id
    assert_valid_markup
    assert_response :success
    assert_tag :tag => 'strong', :content => pln.name

    #MES- If the plan is private, we should get an error
    pln.security_level = Plan::SECURITY_LEVEL_PRIVATE
    pln.save!
    assert_raise(RuntimeError) { get :show, :id => pln.id, :cal_id => plnr.id }

    pln.security_level = Plan::SECURITY_LEVEL_PUBLIC
    pln.save!

    #MES- If the planner visibility level is friends, we should see the plan, but
    # we won't see any details
    plnr.visibility_type = SkobeeConstants::PRIVACY_LEVEL_FRIENDS
    plnr.save!
    get :show, :id => pln.id, :cal_id => plnr.id
    assert_response :success
    assert_no_tag :tag => 'strong', :content => pln.name
    assert_no_tag :tag => 'strong', :content => 'We\'ve got plans (no description).'

  end

  def test_postpone_plans
    login users(:friend_1_of_user)

    #postpone
    original_start = plans(:user_with_friends_plan).start
    original_fuzzy_start = plans(:user_with_friends_plan).fuzzy_start
    get :postpone_plan, :id=> plans(:user_with_friends_plan).id
    assert_redirected_to "planners/schedule_details"

    postponed_plan = plans(:user_with_friends_plan, :force)
    assert_not_equal original_start, postponed_plan .start
    assert_not_equal original_fuzzy_start, postponed_plan.fuzzy_start
  end

  def test_edit_what
    login users(:friend_1_of_user)
    get :show, :id => plans(:user_with_friends_plan).id, :cal_id => users(:friend_1_of_user).planner.id
    assert_success
    assert_valid_markup

    post :edit_what, :id => plans(:user_with_friends_plan).id, :plan_name => "this is the new plan name", :plan_description => "this is the new plan description"
    assert_redirected_to "/plans/show/#{plans(:user_with_friends_plan).id}?cal_id=#{users(:friend_1_of_user).planner.id}"
    assert assigns(:plan).name.match(/this is the new plan name/)
    assert assigns(:plan).description.match(/this is the new plan description/)
  end

  def test_edit_when
    tz = TZInfo::Timezone.get('America/Tijuana')

    login users(:friend_1_of_user)
    get :show, :id => plans(:user_with_friends_plan).id, :cal_id => users(:friend_1_of_user).planner.id
    assert_success
    assert_valid_markup

    post :edit_when, :id => plans(:user_with_friends_plan).id, :dateperiod => Plan::DATE_DESCRIPTION_TOMORROW, :timeperiod => Plan::TIME_DESCRIPTION_LUNCH
    assert_redirected_to "/plans/show/#{plans(:user_with_friends_plan).id}?cal_id=#{users(:friend_1_of_user).planner.id}"
    assert assigns(:plan).dateperiod(tz) == Plan::DATE_DESCRIPTION_TOMORROW
    assert assigns(:plan).timeperiod == Plan::TIME_DESCRIPTION_LUNCH

    get :show, :id => plans(:user_with_friends_plan).id, :cal_id => users(:friend_1_of_user).planner.id
    post :edit_when, :id => plans(:user_with_friends_plan).id, :date_month => "12", :date_day => "12", :date_year  => "2008",
          :plan_hour => "12", :plan_min => "12", :plan_meridian => "AM"
    assert_redirected_to "/plans/show/#{plans(:user_with_friends_plan).id}?cal_id=#{users(:friend_1_of_user).planner.id}"
    assert assigns(:plan).dateperiod(tz) == Plan::DATE_DESCRIPTION_CUSTOM
    assert assigns(:plan).timeperiod == Plan::TIME_DESCRIPTION_CUSTOM
  end

  def test_edit_who
    login users(:friend_1_of_user)
    get :show, :id => plans(:user_with_friends_plan).id, :cal_id => users(:friend_1_of_user).planner.id
    assert_success
    assert_valid_markup

    post :edit_who, :id => plans(:user_with_friends_plan).id, :plan_who => users(:existingbob).login
    assert_redirected_to "/plans/show/#{plans(:user_with_friends_plan).id}?cal_id=#{users(:friend_1_of_user).planner.id}"
    assert assigns(:plan).planners.include?(planners(:existingbob_planner))

    #MGS- test adding a new user to skobee with the who field
    get :show, :id => plans(:user_with_friends_plan).id, :cal_id => users(:friend_1_of_user).planner.id
    post :edit_who, :id => plans(:user_with_friends_plan).id, :plan_who => 'newuser@skobee.com'
    new_user = User.find_by_email('newuser@skobee.com')
    assert !new_user.nil?
    assert assigns(:plan).planners.include?(new_user.planner)
    #MGS- assert that this new user has a contact: friend_1_of_user
    assert new_user.friend_contacts.include?(users(:friend_1_of_user))
  end

  def test_change_privacy
    #MES- The change_privacy function should reverse the privacy of the plan.
    #  Private goes to public, public goes to private.
    login users(:friend_1_of_user)
    pln = plans(:user_with_friends_plan)
    plnr_id = users(:friend_1_of_user).planner.id
    assert_equal Plan::SECURITY_LEVEL_PUBLIC, pln.security_level
    get :show, :id => pln.id, :cal_id => plnr_id

    post :change_privacy, :id => pln.id
    assert_redirected_to "/plans/show/#{pln.id}?cal_id=#{plnr_id}"
    assert_equal Plan::SECURITY_LEVEL_PRIVATE, assigns(:plan).security_level
    assert_equal Plan::SECURITY_LEVEL_PRIVATE, plans(:user_with_friends_plan, true).security_level
  end

  def test_check_security
    #MES- For normal plans, only those who have accepted OR are the owner can edit them

    #MES- Existingbob has not accepted another_plan, but he's the owner
    pln = plans(:another_plan)
    ebob = users(:existingbob)
    assert_equal pln, @controller.check_security(pln.id, false, ebob)
    assert_equal pln, @controller.check_security(pln.id, true, ebob)

    #MES- Longbob HAS accepted another_plan
    lbob = users(:longbob)
    assert_equal pln, @controller.check_security(pln.id, false, lbob)
    assert_equal pln, @controller.check_security(pln.id, true, lbob)

    #MES- Bob isn't on the plan at all
    bob = users(:bob)
    assert_raise(RuntimeError) { @controller.check_security(pln.id, false, bob) }
    assert_raise(RuntimeError) { @controller.check_security(pln.id, true, bob) }

    #MES- Put user_with_friends on the plan, NOT accepted- should not be able to edit
    uwf = users(:user_with_friends)
    uwf_plnr = uwf.planner
    uwf_plnr.add_plan(pln)
    assert_equal pln, @controller.check_security(pln.id, false, uwf)
    assert_raise(RuntimeError) { @controller.check_security(pln.id, true, uwf) }

    #MES- For locked plans, only the owner(s) can edit them
    pln.lock_status = Plan::LOCK_STATUS_OWNERS_ONLY
    pln.save!

    #MES- Existingbob is an owner, but hasn't accepted the plan
    assert_equal pln, @controller.check_security(pln.id, false, ebob)
    assert_equal pln, @controller.check_security(pln.id, true, ebob)

    #MES- Longbob is not an owner
    assert_equal pln, @controller.check_security(pln.id, false, lbob)
    assert_raise(RuntimeError) { @controller.check_security(pln.id, true, lbob) }

    #MES- Bob isn't on the plan at all
    assert_raise(RuntimeError) { @controller.check_security(pln.id, false, bob) }
    assert_raise(RuntimeError) { @controller.check_security(pln.id, true, bob) }

    #MES- user_with_friends hasn't accepted the plan, and is not an owner
    assert_equal pln, @controller.check_security(pln.id, false, uwf)
    assert_raise(RuntimeError) { @controller.check_security(pln.id, true, uwf) }
  end

end


class PlansControllerTest_3 < Test::Unit::TestCase
  fixtures :plans, :planners

  def setup
    @controller = PlansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end


  def test_require_login
    #MES- All pages except show should require login

    #MES- Make sure we're not logged in
    logout

    get :new
    assert_redirect_to_login

    post :create, :plan => {}
    assert_redirect_to_login

    post :update, :id => plans(:first_plan).id
    assert_redirect_to_login
  end
end

class PlansControllerTest_4 < Test::Unit::TestCase
  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :users, :plans, :planners, :planners_plans, :places, :plan_changes, :user_atts, :emails, :user_contacts

  def setup
    @controller = PlansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  def test_comments
    login users(:user_with_friends)

    #add comment
    post :add_change_ajax, :plan_id => plans(:plan_just_for_user_with_friends).id, :change_tb => "this is a new comment"

    assert_success
    assert_tag :tag=>"p", :content => "this is a new comment"

    plan = assigns(:plan)
    comments = plan.plan_changes
    #MGS- we can do this because this should be the only comment
    assert comments.length == 1
    comment_id = comments[0].id

    #edit comment
    post :edit_change_ajax, :change_id=> comment_id, :plan_id => plans(:plan_just_for_user_with_friends).id, "change_edit_tb#{comment_id}" => "this is the edited comment"

    assert_success
    assert_tag :tag=>"p", :content => "this is the edited comment"

    #delete comment
    post :delete_change_ajax, :change_id=> comment_id, :plan_id => plans(:plan_just_for_user_with_friends).id

    plan = assigns(:plan)
    comments = plan.plan_changes
    #MGS- the comment should have been deleted
    assert comments.length == 0


    get :show, :id=> plans(:plan_just_for_user_with_friends).id, :cal_id => users(:user_with_friends).planner.id
    assert_success
    assert_valid_markup


    #MGS- test truncating a long comment
    #add comment
    post :add_change_ajax, :plan_id => plans(:plan_just_for_user_with_friends).id, :change_tb => "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Duis aliquam nisl ullamcorper est. Quisque in dui viverra enim mattis lobortis. Praesent sit amet augue id enim volutpat posuere. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Donec condimentum lacus eget arcu. Suspendisse et velit. Vestibulum a ante a neque tristique vehicula. Sed laoreet, ligula nec imperdiet mattis, pede felis dapibus mauris, sit amet vestibulum lorem elit dapibus tellus. Vivamus vel massa. Ut sagittis, ligula vel laoreet placerat, mi velit dapibus est, vitae dapibus purus nibh vitae nunc. Praesent sit amet lectus. Mauris suscipit mi vel mi faucibus pellentesque. Phasellus sodales rutrum magna. Duis imperdiet dolor sit amet nisl. Etiam magna. Pellentesque molestie venenatis ante. Nullam tellus elit, volutpat eget, elementum eu, rutrum tempus, arcu. Nulla arcu augue, sodales vel, gravida id, viverra nec, magna.Maecenas adipiscing diam vel metus. Aenean risus ipsum, pulvinar in, bibendum vel, auctor ac, tellus. Fusce non ligula nec massa consequat egestas. Etiam bibendum. In hac habitasse platea dictumst. Donec id odio. Curabitur pretium dolor eu leo. Vivamus ornare. Curabitur velit pede, gravida porttitor, malesuada mattis, molestie sit amet, risus. In a orci eu lectus dapibus aliquam. Curabitur faucibus nunc. Donec diam. Sed pede. Praesent a nulla. Praesent pretium. Aenean vestibulum.Integer sagittis neque a mi. Ut commodo blandit odio. Nam augue augue, egestas sit amet, consectetuer in, faucibus at, pede. Praesent a pede eget sem sollicitudin lobortis. Maecenas semper. Praesent tincidunt vestibulum justo. Cras sit amet odio ac urna blandit consequat. Etiam id lorem nec quam lacinia vehicula. Suspendisse consequat faucibus mauris. Aliquam dapibus. Praesent commodo. Proin ultrices, ligula sed iaculis pretium, erat turpis pellentesque velit, eget pretium lorem arcu sit amet felis. Suspendisse potenti.Quisque faucibus pede at enim tincidunt bibendum. Curabitur eu nibh. Aliquam lobortis arcu eu libero. Donec nibh metus, mollis eget, ultrices at, lacinia ut, urna. Sed sollicitudin blandit tellus. Praesent lectus. Cras quis diam. Aliquam massa turpis, adipiscing ac, porttitor a, suscipit et, elit. In hac habitasse platea dictumst. Suspendisse erat odio, dignissim non, rutrum id, sodales vel, elit. Mauris in tortor. Cras in orci ac lectus vestibulum varius. Quisque dignissim sem in massa. Suspendisse turpis sapien, auctor a, cursus a, blandit eu, leo. Mauris vel est. Mauris ultricies dolor varius sem. Sed euismod est vitae velit. Suspendisse luctus auctor mauris.Ut volutpat, arcu nec blandit tristique, sapien justo venenatis odio, vel suscipit ipsum mauris sit amet lacus. Vestibulum felis lacus, vestibulum et, vulputate a, semper eget, magna. Sed convallis luctus diam. Sed feugiat ante blandit neque. Donec sed metus in arcu consequat convallis. Nam volutpat. Ut ante ipsum, fermentum eu, faucibus aliquet, accumsan at, velit. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Nulla facilisi. Nullam elit sapien, rhoncus in, vulputate eget, pharetra ac, elit. Praesent eget orci. Etiam lacus. Ut feugiat enim ac orci. Aenean vitae leo sed lorem imperdiet tempus. Mauris est arcu, hendrerit sit amet, viverra non, volutpat sit amet, erat. Cras porta, orci ac hendrerit convallis, est lorem volutpat velit, eget aliquam quam orci tincidunt dolor.Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Vestibulum ligula purus, ullamcorper at, ultricies placerat, ultricies vitae, lorem. Proin euismod. Maecenas semper enim ultrices neque. Quisque consequat augue eu eros. Pellentesque libero. Cras accumsan. Fusce ut magna. Suspendisse porttitor fringilla metus. Duis felis. Cras pretium orci nec nulla. Etiam fringilla dictum magna. In adipiscing porta tellus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Ut ligula eros, imperdiet feugiat, porttitor ut, convallis ac, ligula. Sed leo arcu, iaculis non, auctor id, luctus eu, sem. Cras et ligula et massa luctus luctus. In hac habitasse platea dictumst. Donec nonummy.Donec quis tortor. Aenean lobortis leo et nisl. Ut volutpat rutrum sapien. In dolor orci, viverra eu, sagittis in, rhoncus eget, mauris. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Fusce eget enim quis risus ornare molestie. Nulla ut est. Maecenas massa urna, porta sit amet, euismod sit amet, lacinia in, tortor. Nunc convallis condimentum nisl. Donec est. Nunc condimentum ipsum gravida nunc. Nulla interdum semper lacus. Vivamus odio turpis, malesuada in, imperdiet nec, aliquam elementum, erat. Phasellus adipiscing condimentum ligula. Quisque rutrum massa non neque. Donec laoreet diam ut leo. Suspendisse dui erat, egestas a, feugiat quis, pharetra vitae, ipsum. Nulla convallis dolor a purus. Sed felis magna, auctor id, pretium et, lobortis rutrum, nibh. Suspendisse massa nunc."
    assert_success
    assert_tag :tag=>"p", :content => "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Duis aliquam nisl ullamcorper est. Quisque in dui viverra enim mattis lobortis. Praesent sit amet augue id enim volutpat posuere. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Donec condimentum lacus eget arcu. Suspendisse et velit. Vestibulum a ante a neque tristique vehicula. Sed laoreet, ligula nec imperdiet mattis, pede felis dapibus mauris, sit amet vestibulum lorem elit dapibus tellus. Vivamus vel massa. Ut sagittis, ligula vel laoreet placerat, mi velit dapibus est, vitae dapibus purus nibh vitae nunc. Praesent sit amet lectus. Mauris suscipit mi vel mi faucibus pellentesque. Phasellus sodales rutrum magna. Duis imperdiet dolor sit amet nisl. Etiam magna. Pellentesque molestie venenatis ante. Nullam tellus elit, volutpat eget, elementum eu, rutrum tempus, arcu. Nulla arcu augue, sodales vel, gravida id, viverra nec, magna.Maecenas adipiscing diam vel metus. Aenean risus ipsum, pulvinar in, bibendum vel, auctor ac, tellus. Fusce non ligula nec massa consequat egestas. Etiam bibendum. In hac habitasse platea dictumst. Donec id odio. Curabitur pretium dolor eu leo. Vivamus ornare. Curabitur velit pede, gravida porttitor, malesuada mattis, molestie sit amet, risus. In a orci eu lectus dapibus aliquam. Curabitur faucibus nunc. Donec diam. Sed pede. Praesent a nulla. Praesent pretium. Aenean vestibulum.Integer sagittis neque a mi. Ut commodo blandit odio. Nam augue augue, egestas sit amet, consectetuer in, faucibus at, pede. Praesent a pede eget sem sollicitudin lobortis. Maecenas semper. Praesent tincidunt vestibulum justo. Cras sit amet odio ac urna blandit consequat. Etiam id lorem nec quam lacinia vehicula. Suspendisse consequat faucibus mauris. Aliquam dapibus. Praesent commodo. Proin ultrices, ligula sed iaculis pretium, erat turpis pellentesque velit, eget pretium lorem arcu sit amet felis. Suspendisse potenti.Quisque faucibus pede at enim tincidunt bibendum. Curabitur eu nibh. Aliquam lobortis arcu eu libero. Donec nibh metus, mollis eget, ultrices at, lacinia ut, urna. Sed sollicitudin blandit tellus. Praesent lectus. Cras quis diam. Aliquam massa turpis, adipiscing ac, porttitor a, suscipit et, elit. In hac habitasse platea dictumst. Suspendisse erat odio, dignissim non, rutrum id, sodales vel, elit. Mauris in tortor. Cras in orci ac lectus vestibulum varius. Quisque dignissim sem in massa. Suspendisse turpis sapien, auctor a, cursus a, blandit eu, leo. Mauris vel est. Mauris ultricies dolor varius sem. Sed euismod est vitae velit. Suspendisse luctus auctor mauris.Ut volutpat, arcu nec blandit tristique, sapien justo venenatis odio, vel suscipit ipsum mauris sit amet lacus. Vestibulum felis lacus, vestibulum et, vulputate a, semper eget, magna. Sed convallis luctus diam. Sed feugiat ante blandit neque. Donec sed metus in arcu consequat convallis. Nam volutpat. Ut ante ipsum, fermentum eu, faucibus aliquet, accumsan at, velit. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Nulla facilisi. Nullam elit sapien, rhoncus in, vulputate eget, pharetra ac, elit. Praesent eget orci. Etiam lacus. Ut feugiat enim ac orci. Aenean vitae leo sed lorem imperdiet tempus. Mauris est arcu, hendrerit sit amet, viverra non, volutpat sit amet, erat. Cras porta, orci ac hendrerit convallis, est lorem volutpat velit, eget aliquam quam orci tincidunt dolor.Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Vestibulum ligula purus, ullamcorper at, ultricies placerat, ultricies vitae, lorem. Proin euismod. Maecenas semper enim ultrices neque. Quisque consequat augue eu eros. Pellentesque libero. Cras accumsan. Fusce ut magna. Suspendisse porttitor fringilla metus. Duis felis. Cras pretium orci nec nulla. Etiam fringilla dictum magna. In adipiscing porta tellus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Ut ligula eros, imperdiet feugiat, porttitor ut, convallis ac, ligula. Sed leo arcu, iaculis non, auctor id, luctus eu, sem. Cras et ligula et"

    get :show, :id=> plans(:plan_just_for_user_with_friends).id, :cal_id => users(:user_with_friends).planner.id
    assert_success
    assert_valid_markup

    #MGS- test that 'Add Comment' link appears when it should
    #MGS- the only accepted user on this plan is user_with_friends_and_friends_cal who has set friend_1_of_user as a friend,
    # so the add comment link should be visible
    login users(:friend_1_of_user)
    get :show, :id => plans(:plan_just_for_user_with_friends_and_friends_cal).id, :cal_id => planners(:user_with_friends_and_friends_cal_planner).id
    assert_success
    assert_tag :tag => "a", :content => "Add Comment", :attributes => { :id => "add-comment" }

    #MGS- user_with_friends is rejected on this plan, so Add Comment link shouldn't be visible,
    # even though user_with_friends has set friend_1_of_user as a friend
    get :show, :id => plans(:solid_plan_in_expiry_window).id, :cal_id => planners(:user_with_friends_planner).id
    assert_success
    assert_no_tag :tag => "a", :content => "Add Comment"
    assert_tag :tag => 'span', :attributes => { :id => "all_details" }
    assert_no_tag :tag => 'div', :content => "Seems like you know someone on this plan."

    #MGS- user_with_friends is invited (not replied) on this plan, so Add Comment link shouldn't be visible,
    # even though user_with_friends has set friend_1_of_user as a friend
    get :show, :id => plans(:first_plan).id, :cal_id => planners(:user_with_friends_planner).id
    assert_success
    assert_no_tag :tag => "a", :content => "Add Comment"
    assert_no_tag :tag => 'div', :content => "Seems like you know someone on this plan."

    #MGS- the only accepted user on this plan is user_with_friends_and_friends_cal who has set friend_1_of_user as a friend,
    # so the add comment link should be visible
    get :show, :id => plans(:future_plan_2).id, :cal_id => planners(:user_with_friends_planner).id
    assert_success
    assert_tag :tag => "a", :content => "Add Comment", :attributes => { :id => "add-comment" }
    assert_tag :tag => 'span', :attributes => { :id => "all_details" }
    assert_tag :tag => 'div', :content => "Seems like you know someone on this plan."

    #MGS- add a comment to this plan
    post :add_change_ajax, :plan_id => plans(:future_plan_2).id, :change_tb => "this plan looks cool"
    assert_success
    assert_tag :tag=>"p", :content => "this plan looks cool"
    plan = assigns(:plan)
    comments = plan.plan_changes
    #MGS- we can do this because this should be the only comment
    assert comments.length == 1

    #MGS- now change the plan status for user_with_friends from accepted to rejected
    users(:user_with_friends).planner.reject_plan(plans(:future_plan_2).id)

    #MGS- since user_with_friends hasn't accepted this plan anymore, friend_1_of_user
    # shouldn't be able to add new comments, but should still be able to edit and delete
    # their previously entered comment
    get :show, :id => plans(:future_plan_2).id, :cal_id => planners(:user_with_friends_planner).id
    assert_success
    assert_no_tag :tag => "a", :content => "Add Comment"
    assert_tag :tag => "a", :content => "Edit", :attributes => { :id => /edit-change/ }
    assert_tag :tag => "a", :content => "Delete"

    #MGS- now change the plan status for user_with_friends back to accepted
    users(:user_with_friends).planner.accept_plan(plans(:future_plan_2), users(:user_with_friends))

    #MGS- remove the contact status betweeen user_with_friends and friend_1_of_user;
    # friend_1_of_user shouldn't be able to add new comments, but should be able to edit his existing comment
    users(:user_with_friends).add_or_update_contact(users(:friend_1_of_user), { :friend_status => User::FRIEND_STATUS_NONE })
    get :show, :id => plans(:future_plan_2).id, :cal_id => planners(:user_with_friends_planner).id
    assert_success
    assert_no_tag :tag => "a", :content => "Add Comment"
    assert_tag :tag => "a", :content => "Edit", :attributes => { :id => /edit-change/ }
    assert_tag :tag => "a", :content => "Delete"
  end
end




class PlansControllerTest_5 < Test::Unit::TestCase
  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :users, :planners, :places, :emails

  def setup
    @controller = PlansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  def test_new
    login

    get :new

    assert_response :success
    assert_template 'new'
    assert_not_nil assigns(:plan)
    assert_valid_markup

    #MGS- test with default place
    get :new, :place => places(:first_place).id
    assert_response :success
    assert_tag :attributes=>{:id => "search_by_name_result_text"}, :content => "#{places(:first_place).name} (#{places(:first_place).location})"
    assert_valid_markup

    #MGS- test with default user
    get :new, :who => users(:friend_2_of_user).id
    assert_response :success
    assert_tag :attributes=>{:id => "plan_who"}, :content => "#{users(:friend_2_of_user).real_name} (#{users(:friend_2_of_user).login})"
    assert_valid_markup
  end

  def test_create
    login users(:bob)

    initial_num_plans = Plan.count

    #MES- View the user's planner, to have something to redirect back to
    get_to_controller(PlannersController.new, :show, { :id => planners(:first_planner).id })

    #MES- Create a plan
    post :create, :plan => {}

    #MES- Check that we were redirected properly, and that the number of plans has grown
    #MES- Note that we have to check redirect via string, since passing in the
    #  hash doesn't match for some reason
    assert_redirected_to "/plans/show/#{assigns(:plan).id}?cal_id=#{users(:bob).planner.id}"
    assert_equal initial_num_plans + 1, Plan.count

    #####################################################################
    # Tests for good plan_who field in plan creation
    #####################################################################
    #MGS- Create a plan with good invitees: existing user, new email, exisiting user by email, some garbage space, duplicate existing user
    post :create, { "plan_who" => "bob,newemail@newemail.com,existingbob@test.com,,,,,bob" }

    #KS- confirm that an email was sent to newemail@newemail.com and bob@test.com
    assert_equal 2, @emails.size
    mail = @emails[0]
    assert_equal "existingbob@test.com", mail.to_addrs[0].to_s
    #MGS- checking the from address
    assert_equal "#{users(:bob).full_name} #{UserNotify::EMAIL_FROM_SUFFIX}", mail.from_addrs[0].name
    mail = @emails[1]
    assert_equal "newemail@newemail.com", mail.to_addrs[0].to_s

    #MGS- confirm that new user was created with this email
    assert_kind_of User, User.find_by_email("newemail@newemail.com")
    #MGS- bob should be added to this new user's contact list
    assert User.find_by_email("newemail@newemail.com").friend_contacts.include?(users(:bob))

    #MGS- confirm that
    assert_redirected_to "/plans/show/#{assigns(:plan).id}?cal_id=#{users(:bob).planner.id}"
    assert_equal initial_num_plans + 2, Plan.count
    #MGS- Create a plan with good invitees: existing user, new email, exisiting user by email, some garbage space, duplicate existing user
    post :create, { "plan_who" => "bob,newemail2@newemail.com,existingbob@test.com,,,,,bob" }

    #MGS- confirm that new user was created with this email
    assert_kind_of User, User.find_by_email("newemail2@newemail.com")

    #MGS- confirm that
    assert_redirected_to "/plans/show/#{assigns(:plan).id}?cal_id=#{users(:bob).planner.id}"
    assert_equal initial_num_plans + 3, Plan.count

    #####################################################################
    # Tests for bad plan_who field in plan creation
    #####################################################################
    #MGS- go to plans contoller first
    get_to_controller(PlansController.new, :new, { :id => planners(:first_planner).id })
    #MGS- Create a plan with bad invitees: existing user, bad format email, good format email
    post :create, { "plan_who" => "bob,dude@scrub.com,scrub@scrubcom" }

    #MGS- ensure accounts werent created for these entries
    assert_nil User.find_by_email("scrub@scrubcom")
    #MGS- make sure this email wasn't created plan though it's valid to test atomicy of action
    assert_nil User.find_by_email("dude@scrub.com")

    #MGS- confirm redirect back to plan editor to fix problems
    assert_rendered_file 'new'
    assert_equal initial_num_plans + 3, Plan.count

    #MGS- Create a plan with bad invitees: existing user, good format email, junk @, junk account
    post :create, { "plan_who" => "bob,newemail77@newemail77.com,,,@,bobby," }

    #MGS- badly formmatted email shouldn't have been created either
    assert_nil User.find_by_email("newemail77@newemail77.com")
    #MGS- test out user helper as well
    assert_nil User.find_by_string("newemail77@newemail77.com")
    assert_nil User.find_by_string("bobby")
    #MGS- confirm redirect back to plan editor to fix problems
    assert_rendered_file 'new'
    assert_equal initial_num_plans + 3, Plan.count


    #MGS- create a plan with a mixed comma/semicolon list
    post :create, { "plan_who" => "bob;newemail55@newemail55.com,existingbob;;,,friend_1_of_user" }
    pln = assigns(:plan)
    assert_redirected_to :action => "show", :id => pln.id, :cal_id => users(:bob).planner.id
    assert_equal 4, pln.planners.length
    assert pln.planners.include?(users(:bob).planner)
    assert pln.planners.include?(users(:existingbob).planner)
    assert pln.planners.include?(users(:friend_1_of_user).planner)
    assert User.find_by_string("newemail55@newemail55.com")
    assert pln.planners.include?(User.find_by_string("newemail55@newemail55.com").planner)
    assert_equal initial_num_plans + 4, Plan.count

    #MGS- test creation adding a new venue, requesting that it be promoted to public
    post :create, {:plan => {:name => "test plan"}, :dateperiod => 7, :timeperiod => 3, :place_origin => "2",
                   :place_name => "new test place", :place_location => "1840 Sacramento St.", :request_public => "on"}
    plan = assigns(:plan)
    place = plan.place
    assert_not_nil plan
    assert_not_nil place
    assert_equal place.name, "new test place"
    assert_equal place.location, "1840 Sacramento St."
    assert_equal place.public, 0
    assert place.public_requested?
    assert_equal initial_num_plans + 5, Plan.count

    #MGS- test creation adding a new venue, requesting that it be promoted to public
    post :create, {:plan => {:name => "another burrito test plan"}, :dateperiod => 7, :timeperiod => 3, :place_origin => "2",
                   :place_name => "panchos borracho", :place_location => "655 Polk St.", :request_public => ""}
    plan = assigns(:plan)
    place = plan.place
    assert_not_nil plan
    assert_not_nil place
    assert_equal plan.name, "another burrito test plan"
    assert_equal place.name, "panchos borracho"
    assert_equal place.location, "655 Polk St."
    assert_equal place.public, 0
    assert !place.public_requested?
    assert_equal initial_num_plans + 6, Plan.count

    #MGS- test creation with a description
    post :create, {:plan=>{:name=>"biking this weekend", :description => "It would be nice to ride out to the cheese factory this weekend."},
                   :plan_who => "", :dateperiod => 7, :timeperiod => 3 }
    plan = assigns(:plan)
    place = plan.place
    assert_not_nil plan
    assert_nil place
    assert_equal "biking this weekend", plan.name
    assert_equal "It would be nice to ride out to the cheese factory this weekend.", plan.description
    assert_equal initial_num_plans + 7, Plan.count

    #MGS- test creation with a bogus who and make sure description and name say in the fields
    post :create, {:plan=>{:name=>"name should persist", :description => "description should persist"},
                   :plan_who => "45045", :dateperiod => 7, :timeperiod => 3 }
    plan = assigns(:plan)
    assert_template 'new'
    assert_tag :tag => "input", :attributes => {:id => "plan_name", :value => "name should persist"}
    assert_tag :tag => "textarea", :content => "description should persist", :attributes => {:id => "plan_description"}
    #MGS- count shouldnt increment
    assert_equal initial_num_plans + 7, Plan.count

    #MGS- test the creation of long comments
    post :create, {:plan=>{:name=>"name should persist",
                   :description => "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Duis aliquam nisl ullamcorper est. Quisque in dui viverra enim mattis lobortis. Praesent sit amet augue id enim volutpat posuere. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Donec condimentum lacus eget arcu. Suspendisse et velit. Vestibulum a ante a neque tristique vehicula. Sed laoreet, ligula nec imperdiet mattis, pede felis dapibus mauris, sit amet vestibulum lorem elit dapibus tellus. Vivamus vel massa. Ut sagittis, ligula vel laoreet placerat, mi velit dapibus est, vitae dapibus purus nibh vitae nunc. Praesent sit amet lectus. Mauris suscipit mi vel mi faucibus pellentesque. Phasellus sodales rutrum magna. Duis imperdiet dolor sit amet nisl. Etiam magna. Pellentesque molestie venenatis ante. Nullam tellus elit, volutpat eget, elementum eu, rutrum tempus, arcu. Nulla arcu augue, sodales vel, gravida id, viverra nec, magna.Maecenas adipiscing diam vel metus. Aenean risus ipsum, pulvinar in, bibendum vel, auctor ac, tellus. Fusce non ligula nec massa consequat egestas. Etiam bibendum. In hac habitasse platea dictumst. Donec id odio. Curabitur pretium dolor eu leo. Vivamus ornare. Curabitur velit pede, gravida porttitor, malesuada mattis, molestie sit amet, risus. In a orci eu lectus dapibus aliquam. Curabitur faucibus nunc. Donec diam. Sed pede. Praesent a nulla. Praesent pretium. Aenean vestibulum.Integer sagittis neque a mi. Ut commodo blandit odio. Nam augue augue, egestas sit amet, consectetuer in, faucibus at, pede. Praesent a pede eget sem sollicitudin lobortis. Maecenas semper. Praesent tincidunt vestibulum justo. Cras sit amet odio ac urna blandit consequat. Etiam id lorem nec quam lacinia vehicula. Suspendisse consequat faucibus mauris. Aliquam dapibus. Praesent commodo. Proin ultrices, ligula sed iaculis pretium, erat turpis pellentesque velit, eget pretium lorem arcu sit amet felis. Suspendisse potenti.Quisque faucibus pede at enim tincidunt bibendum. Curabitur eu nibh. Aliquam lobortis arcu eu libero. Donec nibh metus, mollis eget, ultrices at, lacinia ut, urna. Sed sollicitudin blandit tellus. Praesent lectus. Cras quis diam. Aliquam massa turpis, adipiscing ac, porttitor a, suscipit et, elit. In hac habitasse platea dictumst. Suspendisse erat odio, dignissim non, rutrum id, sodales vel, elit. Mauris in tortor. Cras in orci ac lectus vestibulum varius. Quisque dignissim sem in massa. Suspendisse turpis sapien, auctor a, cursus a, blandit eu, leo. Mauris vel est. Mauris ultricies dolor varius sem. Sed euismod est vitae velit. Suspendisse luctus auctor mauris.Ut volutpat, arcu nec blandit tristique, sapien justo venenatis odio, vel suscipit ipsum mauris sit amet lacus. Vestibulum felis lacus, vestibulum et, vulputate a, semper eget, magna. Sed convallis luctus diam. Sed feugiat ante blandit neque. Donec sed metus in arcu consequat convallis. Nam volutpat. Ut ante ipsum, fermentum eu, faucibus aliquet, accumsan at, velit. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Nulla facilisi. Nullam elit sapien, rhoncus in, vulputate eget, pharetra ac, elit. Praesent eget orci. Etiam lacus. Ut feugiat enim ac orci. Aenean vitae leo sed lorem imperdiet tempus. Mauris est arcu, hendrerit sit amet, viverra non, volutpat sit amet, erat. Cras porta, orci ac hendrerit convallis, est lorem volutpat velit, eget aliquam quam orci tincidunt dolor.Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Vestibulum ligula purus, ullamcorper at, ultricies placerat, ultricies vitae, lorem. Proin euismod. Maecenas semper enim ultrices neque. Quisque consequat augue eu eros. Pellentesque libero. Cras accumsan. Fusce ut magna. Suspendisse porttitor fringilla metus. Duis felis. Cras pretium orci nec nulla. Etiam fringilla dictum magna. In adipiscing porta tellus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Ut ligula eros, imperdiet feugiat, porttitor ut, convallis ac, ligula. Sed leo arcu, iaculis non, auctor id, luctus eu, sem. Cras et ligula et massa luctus luctus. In hac habitasse platea dictumst. Donec nonummy.Donec quis tortor. Aenean lobortis leo et nisl. Ut volutpat rutrum sapien. In dolor orci, viverra eu, sagittis in, rhoncus eget, mauris. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Fusce eget enim quis risus ornare molestie. Nulla ut est. Maecenas massa urna, porta sit amet, euismod sit amet, lacinia in, tortor. Nunc convallis condimentum nisl. Donec est. Nunc condimentum ipsum gravida nunc. Nulla interdum semper lacus. Vivamus odio turpis, malesuada in, imperdiet nec, aliquam elementum, erat. Phasellus adipiscing condimentum ligula. Quisque rutrum massa non neque. Donec laoreet diam ut leo. Suspendisse dui erat, egestas a, feugiat quis, pharetra vitae, ipsum. Nulla convallis dolor a purus. Sed felis magna, auctor id, pretium et, lobortis rutrum, nibh. Suspendisse massa nunc."},
                   :plan_who => "", :dateperiod => 7, :timeperiod => 3 }
    plan = assigns(:plan)
    assert plan.description == "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Duis aliquam nisl ullamcorper est. Quisque in dui viverra enim mattis lobortis. Praesent sit amet augue id enim volutpat posuere. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Donec condimentum lacus eget arcu. Suspendisse et velit. Vestibulum a ante a neque tristique vehicula. Sed laoreet, ligula nec imperdiet mattis, pede felis dapibus mauris, sit amet vestibulum lorem elit dapibus tellus. Vivamus vel massa. Ut sagittis, ligula vel laoreet placerat, mi velit dapibus est, vitae dapibus purus nibh vitae nunc. Praesent sit amet lectus. Mauris suscipit mi vel mi faucibus pellentesque. Phasellus sodales rutrum magna. Duis imperdiet dolor sit amet nisl. Etiam magna. Pellentesque molestie venenatis ante. Nullam tellus elit, volutpat eget, elementum eu, rutrum tempus, arcu. Nulla arcu augue, sodales vel, gravida id, viverra nec, magna.Maecenas adipiscing diam vel metus. Aenean risus ipsum, pulvinar in, bibendum vel, auctor ac, tellus. Fusce non ligula nec massa consequat egestas. Etiam bibendum. In hac habitasse platea dictumst. Donec id odio. Curabitur pretium dolor eu leo. Vivamus ornare. Curabitur velit pede, gravida porttitor, malesuada mattis, molestie sit amet, risus. In a orci eu lectus dapibus aliquam. Curabitur faucibus nunc. Donec diam. Sed pede. Praesent a nulla. Praesent pretium. Aenean vestibulum.Integer sagittis neque a mi. Ut commodo blandit odio. Nam augue augue, egestas sit amet, consectetuer in, faucibus at, pede. Praesent a pede eget sem sollicitudin lobortis. Maecenas semper. Praesent tincidunt vestibulum justo. Cras sit amet odio ac urna blandit consequat. Etiam id lorem nec quam lacinia vehicula. Suspendisse consequat faucibus mauris. Aliquam dapibus. Praesent commodo. Proin ultrices, ligula sed iaculis pretium, erat turpis pellentesque velit, eget pretium lorem arcu sit amet felis. Suspendisse potenti.Quisque faucibus pede at enim tincidunt bibendum. Curabitur eu nibh. Aliquam lobortis arcu eu libero. Donec nibh metus, mollis eget, ultrices at, lacinia ut, urna. Sed sollicitudin blandit tellus. Praesent lectus. Cras quis diam. Aliquam massa turpis, adipiscing ac, porttitor a, suscipit et, elit. In hac habitasse platea dictumst. Suspendisse erat odio, dignissim non, rutrum id, sodales vel, elit. Mauris in tortor. Cras in orci ac lectus vestibulum varius. Quisque dignissim sem in massa. Suspendisse turpis sapien, auctor a, cursus a, blandit eu, leo. Mauris vel est. Mauris ultricies dolor varius sem. Sed euismod est vitae velit. Suspendisse luctus auctor mauris.Ut volutpat, arcu nec blandit tristique, sapien justo venenatis odio, vel suscipit ipsum mauris sit amet lacus. Vestibulum felis lacus, vestibulum et, vulputate a, semper eget, magna. Sed convallis luctus diam. Sed feugiat ante blandit neque. Donec sed metus in arcu consequat convallis. Nam volutpat. Ut ante ipsum, fermentum eu, faucibus aliquet, accumsan at, velit. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Nulla facilisi. Nullam elit sapien, rhoncus in, vulputate eget, pharetra ac, elit. Praesent eget orci. Etiam lacus. Ut feugiat enim ac orci. Aenean vitae leo sed lorem imperdiet tempus. Mauris est arcu, hendrerit sit amet, viverra non, volutpat sit amet, erat. Cras porta, orci ac hendrerit convallis, est lorem volutpat velit, eget aliquam quam orci tincidunt dolor.Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Vestibulum ligula purus, ullamcorper at, ultricies placerat, ultricies vitae, lorem. Proin euismod. Maecenas semper enim ultrices neque. Quisque consequat augue eu eros. Pellentesque libero. Cras accumsan. Fusce ut magna. Suspendisse porttitor fringilla metus. Duis felis. Cras pretium orci nec nulla. Etiam fringilla dictum magna. In adipiscing porta tellus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Ut ligula eros, imperdiet feugiat, porttitor ut, convallis ac, ligula. Sed leo arcu, iaculis non, auctor id, luctus eu, sem. Cras et ligula et"
    assert_equal initial_num_plans + 8, Plan.count

    #####################################################################
    # Tests for adding a place in plan creation
    #####################################################################
    #KS- make sure there is no place called 'kickass place' in the system
    assert_nil Place.find(:first, :conditions => ['name = :name', {:name => '<font size="33">kickass place</font>'}])
    users(:bob).set_notifications_to_default
    @emails.clear
    post :create,
      {
        :place_origin => PlansController::PLACE_NEW_PLACE,
        :place_name => '<font size="33">kickass place</font>',
        :place_location => '94103',
        :place_phone => '555-555-5555',
        :place_url => 'http://www.skobee.com',
        "plan_who" => "bob"
      }
    assert_equal 1, @emails.length

    #KS- make sure the html is escaped
    assert_match(/&lt;font size=&quot;33&quot;&gt;kickass place&lt;\/font&gt;/, @emails[0].body)

    place = Place.find(:first, :conditions => ['name = :name', {:name => '<font size="33">kickass place</font>'}])
    assert_equal '94103', place.location
    assert_equal '5555555555', place.phone
    assert_equal 'http://www.skobee.com', place.url
  end
end


class PlansControllerTest_6 < Test::Unit::TestCase
  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :users, :plans, :places, :emails

  def setup
    @controller = PlansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  #KS- test editing the where of a plan inplace
  def test_edit_where
    #KS- make sure the place is what we expect it to be initially
    plan = plans(:first_plan)
    assert_equal places(:first_place), plan.place

    login users(:user_with_friends)

    @emails.clear
    post :edit_where, { :place_origin => PlansController::PLACE_FOUND_BY_NAME, :place_id => places(:another_place).id, :id => plan.id }
    plan = plans(:first_plan, :force)
    assert_equal places(:another_place).id, plan.place_id

    #KS- email notifications should have been sent out
    assert_equal 2, @emails.length

    #KS- try creating a new plan with no place, then editing the place to add a new place
    #(it should send out a proper notification email)
    plan_count = Plan.count
    @request.user_obj = nil
    post :create, :plan => { :name => "test_plan123fark" }
    assert_equal plan_count + 1, Plan.count
    test_plan = Plan.find(:first, :conditions => ["name = :name", {:name => 'test_plan123fark'}])

    #KS- invite someone so they will get a notification email
    post :edit_who, :id => test_plan.id, :plan_who => users(:existingbob).login

    #KS- have existingbob accept the invite
    users(:existingbob).planner.accept_plan(test_plan)

    #KS- do the place edit
    @emails.clear
    post :edit_where, { :place_origin => PlansController::PLACE_FOUND_BY_NAME, :place_id => places(:place_owned_by_bob).id, :id => test_plan.id }

    #KS- check to make sure the notification email went out
    assert_equal 1, @emails.length
  end

  def test_created_plan_delivery
    #MES- This test goes with test_created_plan in the user_notify_test.rb file (the unit test.)
    # We want to test that the URLs delivered, etc., work right, so we need to
    # do controller stuff- we can't do it all in unit tests.

    #MES- If we created a new place, the email should contain suggestions of alternate
    # places that the user MAY have intended.

    plan = plans(:second_plan_for_place_stats)
    UserNotify.deliver_created_plan(users(:bob), plan, true)
    assert_equal 1, @emails.length
    #MES- The sent email should include URLs for alternate place suggestions
    # AND those URLs should work!
    first_place = places(:first_place)
    assert_not_nil = @emails[0].plaintext_body.match(/plans\/update\/#{plan.id}\?place_id=#{first_place.id}&place_origin=0/)

    login users(:user_with_contacts)
    get :update, :id => plan.id, :place_id => first_place.id, :place_origin => 0
    plan = plans(:second_plan_for_place_stats, :force)
    assert_equal first_place, plan.place
  end
end





class PlansControllerTest_7 < Test::Unit::TestCase

  fixtures :users, :planners, :emails

  def setup
    @controller = PlansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  def test_date_validation
    #MGS- instead of validating a lot of date data client-side, we accept it to the server and make
    # some pseudo-intelligent defaults with the data
    # this functional test tests that pseudo-intelligence for specific dates
    login
    #MES- View the user's planner, to have something to redirect back to
    get_to_controller(PlannersController.new, :show, { :id => planners(:first_planner).id })

    #MGS- timezone should be this one, unless it's not...
    tz = TZInfo::Timezone.get('America/Tijuana')

    #MGS- Create a plan with a specific date
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"11", :date_year => "2005", :date_month =>"11"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)

    #MGS- Create a plan with a specific date and only a two digit year
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"11", :date_year => "07", :date_month =>"11"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)
    assert_equal 2007, assigns(:plan).start_in_tz(tz).year

    #MGS- Create a plan with a specific date and only a 1 digit year, should default to the current year
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"11", :date_year => "7", :date_month =>"11"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)
    assert_equal tz.now.year, assigns(:plan).start_in_tz(tz).year

    #MGS- Create a plan with a specific date and only a 3 digit year, should default to the current year
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"11", :date_year => "007", :date_month =>"11"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)
    assert_equal tz.now.year, assigns(:plan).start_in_tz(tz).year

    #MGS- Create a plan with alpha chars for the year
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"11", :date_year => "abcd", :date_month =>"11"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)
    assert_equal tz.now.year, assigns(:plan).start_in_tz(tz).year

    #MGS- Create a plan with alpha chars for the year
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"11", :date_year => "fv#", :date_month =>"11"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)
    assert_equal tz.now.year, assigns(:plan).start_in_tz(tz).year

    #MGS- Create a plan with bogus months
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"2", :date_year => "2005", :date_month =>"14"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)
    assert_equal tz.now.mon, assigns(:plan).start_in_tz(tz).mon

    #MGS- Create a plan with bogus month
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"2", :date_year => "2005", :date_month =>"sdf"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)
    assert_equal tz.now.mon, assigns(:plan).start_in_tz(tz).mon

    #MGS- Create a plan with bogus month
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"2", :date_year => "2005", :date_month =>"0"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)
    assert_equal tz.now.mon, assigns(:plan).start_in_tz(tz).mon

    #MGS- Create a plan with a correct month
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"21", :date_year => "2006", :date_month =>"6"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)
    assert_equal 6, assigns(:plan).start_in_tz(tz).mon

    #MGS- Create a plan with a bogus day
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"31", :date_year => "2006", :date_month =>"6"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)
    assert_equal 1, assigns(:plan).start_in_tz(tz).day
    assert_equal 7, assigns(:plan).start_in_tz(tz).mon

    #MGS- Create a plan with a bogus day
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"sr", :date_year => "2016", :date_month =>"7"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)
    assert_equal tz.now.day, assigns(:plan).start_in_tz(tz).day

    #MGS- Create a plan with a legit day
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "0", :date_day =>"31", :date_year => "2006", :date_month =>"10"
    assert_equal Plan::DATE_DESCRIPTION_CUSTOM, assigns(:plan).dateperiod(tz)
    assert_equal 31, assigns(:plan).start_in_tz(tz).day
    assert_equal 10, assigns(:plan).start_in_tz(tz).mon
  end

  def test_time_validation
    #MGS- instead of validating a lot of date data client-side, we accept it to the server and make
    # some pseudo-intelligent defaults with the data
    # this functional test tests that pseudo-intelligence
    login
    #MES- View the user's planner, to have something to redirect back to
    get_to_controller(PlannersController.new, :show, { :id => planners(:first_planner).id })

    #MGS- timezone should be this one, unless it's not...
    tz = TZInfo::Timezone.get('America/Tijuana')

    #MGS- Create a plan with a fuzzy time
    post :create, :controller=> "plans", :plan => { :name => ""}, :timeperiod => "3", :dateperiod => "1", :date_day =>"", :date_year => "", :date_month =>""
    assert_equal Plan::TIME_DESCRIPTION_DINNER, assigns(:plan).timeperiod

    #MGS- Create a plan with a good specific time
    post :create, :controller=> "plans", :plan => { :name => ""}, :plan_meridian=>"AM", :plan_hour=>"12", :plan_min=>"12", :timeperiod => "0", :dateperiod => "1"
    assert_equal Plan::TIME_DESCRIPTION_CUSTOM, assigns(:plan).timeperiod
    assert_equal 0, assigns(:plan).start_in_tz(tz).hour
    assert_equal 12, assigns(:plan).start_in_tz(tz).min

    #MGS- Create a plan with a good specific time
    post :create, :controller=> "plans", :plan => { :name => ""}, :plan_meridian=>"AM", :plan_hour=> "12", :plan_min=>"12", :timeperiod => "0", :dateperiod => "1"
    assert_equal Plan::TIME_DESCRIPTION_CUSTOM, assigns(:plan).timeperiod
    assert_equal 0, assigns(:plan).start_in_tz(tz).hour
    assert_equal 12, assigns(:plan).start_in_tz(tz).min

    #MGS- Create a plan with a specific time with currently unallowed hour
    post :create, :controller=> "plans", :plan => { :name => ""}, :plan_meridian=>"AM", :plan_hour=>"22", :plan_min=>"12", :timeperiod => "0", :dateperiod => "1"
    assert_equal Plan::TIME_DESCRIPTION_DINNER, assigns(:plan).timeperiod

    #MGS- Create a plan with a specific time with null our
    post :create, :controller=> "plans", :plan => { :name => ""}, :plan_meridian=>"PM", :plan_hour=> "", :plan_min=>"44", :timeperiod => "0", :dateperiod => "1"
    assert_equal Plan::TIME_DESCRIPTION_DINNER, assigns(:plan).timeperiod

    #MGS- Create a plan with a specific time with bad hour
    post :create, :controller=> "plans", :plan => { :name => ""}, :plan_meridian=>"PM", :plan_hour=> "44", :plan_min=>"44", :timeperiod => "0", :dateperiod => "1"
    assert_equal Plan::TIME_DESCRIPTION_DINNER, assigns(:plan).timeperiod

    #MGS- Create a plan with a specific time; hours cant be 0 but minutes can
    post :create, :controller=> "plans", :plan => { :name => ""}, :plan_meridian=>"PM", :plan_hour=> "1", :plan_min=>"", :timeperiod => "0", :dateperiod => "1"
    assert_equal Plan::TIME_DESCRIPTION_CUSTOM, assigns(:plan).timeperiod
    assert_equal 13, assigns(:plan).start_in_tz(tz).hour
    assert_equal 0, assigns(:plan).start_in_tz(tz).min

    #MGS- Create a plan with a specific time with bad hour
    post :create, :controller=> "plans", :plan => { :name => ""}, :plan_meridian=>"PM", :plan_hour=> "aa", :plan_min=>"33", :timeperiod => "0", :dateperiod => "1"
    assert_equal Plan::TIME_DESCRIPTION_DINNER, assigns(:plan).timeperiod
  end
end




class PlansControllerTest_8 < Test::Unit::TestCase
  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :users, :plans, :planners, :planners_plans, :places, :emails, :plan_changes

  def setup
    @controller = PlansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  def test_revert
    user = users(:existingbob)
    login user
    #MES- Test the revert functionality

    pln = plans(:another_plan)
    cal = planners(:existingbob_planner, :force)
    cal.accept_plan(pln)
    #MES- Create a change to revert to
    original_place_id = pln.place.id
    assert_not_equal original_place_id, places(:another_place).id
    pln.checkpoint_for_revert(user)
    pln.place = places(:another_place)
    pln.save

    #MES- Revert
    pc = pln.plan_changes.select { |pc| PlanChange::CHANGE_TYPE_PLACE == pc.change_type}.min{ |a,b| a.id <=> b.id }
    get :revert, :id => pln.id, :change_id => pc.id

    #MES- Did it revert?
    pln = plans(:another_plan, :force)
    assert_equal original_place_id, pln.place.id

    #MGS- make sure you can't revert, unless you are accepted on the plan...should get a flash
    cal.reject_plan(pln)
    get :revert, :id => pln.id, :change_id => pln.plan_changes[0].id
    assert flash[:error].match(/Whoops. Can't change the plans when your status is set to I'm Out./)
  end

  def test_security
    login

    assert_raise(RuntimeError) { post :update, :id => plans(:another_plan).id }
    assert_raise(RuntimeError) { get :show, :id => plans(:another_plan).id, :cal_id => users(:bob).planner.id }
  end

  def test_did_not_create
    #MES- "Did not create" doesn't require login, but does require
    # a token
    usr = users(:user_with_friends)
    get :did_not_create, :id => plans(:first_plan).id, :user_id => usr.id, :token => usr.generate_security_token
    assert_success
  end


  def test_public_private_places
    #MGS- test the public private place viewing rules for plans pages (see bug #765)
    existingbob = users(:existingbob)
    #MGS- easier to just accept plan here than adding it to the fixtures
    existingbob.planner.accept_plan(plans(:plan_with_a_private_place), nil, nil, Plan::STATUS_ACCEPTED)

    login existingbob
    get :show, :id => plans(:plan_with_a_private_place).id, :cal_id => existingbob.planner.id
    assert_success
    assert_tag :tag => 'a', :content => 'requested public place'
    assert_no_tag :tag => 'h3', :content => 'The location is private for now'
    assert_tag :tag => 'span', :attributes => { :id => "owner_view" }

    #MGS- now login as friend_2_of_user as exisitngbob has set his as a friend....not that this should matter for this test
    login users(:friend_2_of_user)
    get :show, :id => plans(:plan_with_a_private_place).id, :cal_id => existingbob.planner.id
    assert_success
    assert_no_tag :tag => 'a', :content => 'requested public place'
    assert_tag :tag => 'h3', :content => 'The location is private for now'
    assert_tag :tag => 'span', :attributes => { :id => "all_details" }

    #MGS- now add friend_2_of_user to the invite list
    users(:friend_2_of_user).planner.accept_plan(plans(:plan_with_a_private_place), nil, nil, Plan::STATUS_INVITED)
    login users(:friend_2_of_user)
    get :show, :id => plans(:plan_with_a_private_place).id, :cal_id => existingbob.planner.id
    assert_success
    assert_tag :tag => 'a', :content => 'requested public place'
    assert_no_tag :tag => 'h3', :content => 'The location is private for now'
    assert_tag :tag => 'span', :attributes => { :id => "owner_view" }
  end

end



class PlansControllerTest_9 < Test::Unit::TestCase
  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :users, :places, :emails

  def setup
    @controller = PlansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  def test_places_autocomplete
    login

    post :auto_complete_for_place_list, :place_search => "I a"
    assert_success

    assert_equal "[[4],[\"I am a really good place to search for, and abcde\"],[\"\"],[\"i am a really good place to search for and abcde\"]]", @response.body
  end

  def test_search_venues_ajax
    login
    post :search_venues_ajax, :fulltext=>"p", :location=>94111, :max_distance=>"5", :template=>"venue_results", :require_address=>"1", :private_venues_ok => "1"
  end
end


class PlansControllerTest_10 < Test::Unit::TestCase

  fixtures :users, :planners, :planners_plans, :emails, :user_atts, :plans

  def setup
    @controller = PlansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end


  def test_view_plan_not_logged_in

    #MES- Start by making a plan, to create emails that contain URLs we can
    # use to get to plans while NOT logged in.
    login users(:bob)

    #MGS- Create a plan with good invitees: existing user, new email, exisiting user by email, some garbage space, duplicate existing user
    post :create, { "plan_who" => "bob,existingbob@test.com" }

    #MES- This should send an email to existingbob for the plan
    assert_equal 1, @emails.size
    mail = @emails[0]
    assert_equal "existingbob@test.com", mail.to_addrs[0].to_s
    #MGS- checking the From address
    assert_equal "#{users(:bob).full_name} #{UserNotify::EMAIL_FROM_SUFFIX}", mail.from_addrs[0].name

    #MES- Get the plan ID from the email body.  The URL will look like:
    # http://localhost:3000/plans/show/61?cal_id=1&user_id=2&ci0=plan61&cn=1&ckey=ab6feb698a029ea6b2850a4121580915eff8f736
    body = mail.plaintext_body
    m = body.match(/plans\/show\/([0-9]*)?/)
    plan_id = m[1].to_i

    #MES- From the same URL, get the querystring arguments, like:
    # cal_id=1&user_id=2&ci0=plan58&cn=1&ckey=7a6aa26cfa948b9127c4c45004897ee295386eb7
    m = body.match(/cal_id=.*ckey=[a-zA-Z0-9]*/)

    #MES- Break the QS into the parts we'll pass into get methods
    map = m[0].querystring_to_map

    #MES- We should be able to see this plan using the QS
    # info, regardless of whether we're logged in
    map['id'] = plan_id
    get :show, map
    assert_success

    logout
    get :show, map
    assert_success

    #MES- Once we've used that URL, we should be able to see that plan again, even
    # without the QS arguments
    plnr = users(:bob).planner
    planner_id = plnr.id
    get :show, :id => plan_id, :cal_id => planner_id
    assert_success

    #MES- But we should not be able to see OTHER plans, regardless of whether
    # we pass in the QS arguments
    get :show, :id => plans(:another_plan).id, :cal_id => planner_id
    assert_redirect_to_login
    map['id'] = plans(:another_plan).id
    get :show, map
    assert_redirect_to_login

    #MES- If we log back in as the relevant user, we CAN see those things
    login users(:existingbob)
    get :show, :id => plans(:another_plan).id, :cal_id => users(:bob).planner.id
    assert_success
    get :show, :id => plan_id, :cal_id => users(:bob).planner.id
    assert_success

  end

  def test_view_status
    #MES- If status is In, Interested, or Out, does the UI show the user in the correct category?
    login users(:bob)

    #MES- Create a plan with another user
    #MGS- add more than 8 users to this plan to show the text invitee view
    post :create, { "plan_who" => "existingbob@test.com,a@a.com,b@b.com,c@c.com,d@d.com,e@e.com,f@f.com,g@g.com,h@h.com,j@j.com" }
    plan = assigns(:plan)
    get :show, :id => plan.id
    assert_tag :tag => 'a', :content => "#{users(:existingbob).login}", :ancestor => {:tag => 'li', :attributes => {:class => 'pending'}}
    assert_tag :tag => 'a', :content => "#{users(:bob).login}", :ancestor => {:tag => 'li', :attributes => {:class => 'accepted'}}

    #MES- If existingbob changes his status to interested, we should see that.
    users(:existingbob).planner.accept_plan(plan, nil, nil, Plan::STATUS_INTERESTED)
    get :show, :id => plan.id
    assert_tag :tag => 'a', :content => "#{users(:existingbob).login}", :ancestor => {:tag => 'li', :attributes => {:class => 'interested'}}
    assert_tag :tag => 'a', :content => "#{users(:bob).login}", :ancestor => {:tag => 'li', :attributes => {:class => 'accepted'}}

    #MGS- create a plan with just one user
    post :create, { "plan_who" => "existingbob@test.com" }
    plan = assigns(:plan)
    get :show, :id => plan.id
    assert_tag :tag => 'a', :content => "#{users(:existingbob).login}"
  end

  def test_cancel_uncancel
    #MES- Test that the cancel action works
    usr = users(:existingbob)
    login usr
    pln = plans(:another_plan)
    #MES- Should NOT be cancelled to begin with
    pln.planners.each do | plnr |
      assert_not_equal Plan::STATUS_CANCELLED, plnr.cal_pln_status.to_i
    end

    #MES- Cancel it
    post :cancel, :id => pln.id
    pln = plans(:another_plan, true)
    #MES- Should ALL be cancelled
    pln.planners.each do | plnr |
      assert_equal Plan::STATUS_CANCELLED, plnr.cal_pln_status.to_i
    end
    #MES- There should be one notification- longbob will get a notification,
    #  but existingbob will not (since existingbob made the change...)
    assert_equal 1, @emails.length
    assert_equal users(:longbob).email, @emails[0].to_addrs[0].to_s
    assert_equal "#{pln.name} is canceled", @emails[0].subject
    @emails.clear

    #MES- Uncancel it
    post :uncancel, :id => pln.id
    pln = plans(:another_plan, true)
    #MES- Should ALL be invited EXCEPT the person who cancelled
    pln.planners.each do | plnr |
      if plnr.id == usr.planner.id
        assert_equal Plan::STATUS_ACCEPTED, plnr.cal_pln_status.to_i
      else
        assert_equal Plan::STATUS_INVITED, plnr.cal_pln_status.to_i
      end
    end
    #MES- There should be one notification, to longbob
    assert_equal 1, @emails.length
    assert_equal users(:longbob).email, @emails[0].to_addrs[0].to_s
    assert_equal "#{pln.name} is reinstated", @emails[0].subject
  end
end



class PlansControllerTest_11 < Test::Unit::TestCase
  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :users, :plans, :planners, :planners_plans, :emails, :user_atts, :places

  def setup
    @controller = PlansController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  def test_update
    login users(:existingbob)

    #MES- View the user's planner, to have something to redirect back to
    get_to_controller(PlannersController.new, :show, { :id => planners(:first_planner).id })

    guid = '85FF82D68D7A4fb3AC7A0963CF2365DD'
    post :update,
         :id => plans(:another_plan).id,
         :plan => { :name => guid },
         :place_id => places(:another_place).id,
         :place_origin => PlansController::PLACE_FOUND_BY_NAME,
         :plan_who => "newemail@newemail.com,,, longbob@test.com"
    #MGS- check that we were redirected to the plan we just updated, not the plan we originally came from
    #MES- Note that we have to check redirect via string, since passing in the
    #  hash doesn't match for some reason
    assert_redirected_to "/plans/show/#{plans(:another_plan).id}?cal_id=#{users(:existingbob).planner.id}"
    #MES- Check that the name actually got changed
    pln = plans(:another_plan, :force)
    assert_equal guid, pln.name, 'Update did not alter name of plan'

    #KS- verify that the invite email was sent to newemail@newemail.com (there should be no notification email)
    newemail_emails = @emails.find_all{|email| email.to[0] == "newemail@newemail.com"}
    assert_equal 1, newemail_emails.length
    invite_email = newemail_emails[0]
    assert invite_email.body.match(/Your friends are using Skobee to make plans and you\'re invited!/)
    assert invite_email.body.match(/You can also set your RSVP status by replying to this email/)

    #KS- verify that the update email was sent to longbob
    longbob_emails = @emails.find_all{|email| email.to[0] == "longbob@test.com"}
    assert_equal 1, longbob_emails.size
    mail = longbob_emails[0]
    assert_equal "longbob@test.com", mail.to_addrs[0].to_s
    #MGS- check the From name
    assert_equal "#{users(:existingbob).full_name} #{UserNotify::EMAIL_FROM_SUFFIX}", mail.from_addrs[0].name
  end

  def test_hcal
    login
    get :new_hcal
    assert_success
  end

  def test_sidebar_regulars
    #MES- We're basically just testing that the method doesn't throw, and returns valid HTML
    login
    get :sidebar_regulars
    assert_success
  end

  def test_sidebar_touchlist
    #MES- We're basically just testing that the method doesn't throw, and returns valid HTML
    login
    get :sidebar_touchlist
    assert_success
  end

  def test_remove_user
    login users(:existingbob)
    longbob = users(:longbob)
    plan = plans(:solid_plan_in_expiry_window)
    get :show, :id => plan.id, :cal_id => planners(:existingbob_planner).id
    assert_success

    assert plan.planners.include?(longbob.planner)
    assert_equal Plan::STATUS_ACCEPTED, plan.planners.find(longbob.planner.id).cal_pln_status.to_i

    #MGS- try to remove
    post :edit_who, :id => plan.id, :plan_remove_who => longbob.login
    assert_redirect
    assert flash[:notice].match("successfully removed from the plan.")

    assert plan.planners.include?(longbob.planner)
    assert_equal Plan::STATUS_NO_RELATION, plan.planners.find(longbob.planner.id).cal_pln_status.to_i

    #MGS- now try with an add and a double remove
    get :show, :id => plan.id, :cal_id => planners(:existingbob_planner).id
    assert_success

    assert plan.planners.include?(longbob.planner)
    assert_equal Plan::STATUS_NO_RELATION, plan.planners.find(longbob.planner.id).cal_pln_status.to_i

    #MGS- try to remove
    plan = plans(:solid_plan_in_expiry_window, :force)
    not_a_friend = users(:not_a_friend)
    user_with_contacts = users(:user_with_contacts)
    unregistered_user = users(:unregistered_user)

    #MGS- this will remove unregistered_user from the plan and add longbob and notafriend back as invited
    #MGS- user with contacts is already on the plan, and is added and removed....the remove should always win
    post :edit_who, :id => plan.id, :plan_remove_who => "#{unregistered_user.login}, #{user_with_contacts.login}",
                    :plan_who => "#{not_a_friend.login}, #{longbob.login}, #{user_with_contacts.login}"
    assert_redirect
    assert flash[:notice].match("successfully removed from the plan.")

    assert plan.planners.include?(longbob.planner)
    assert_equal Plan::STATUS_INVITED, plan.planners.find(longbob.planner.id).cal_pln_status.to_i
    assert plan.planners.include?(not_a_friend.planner)
    assert_equal Plan::STATUS_INVITED, plan.planners.find(not_a_friend.planner.id).cal_pln_status.to_i
    assert plan.planners.include?(unregistered_user.planner)
    assert_equal Plan::STATUS_NO_RELATION, plan.planners.find(unregistered_user.planner.id).cal_pln_status.to_i
    assert plan.planners.include?(user_with_contacts.planner)
    assert_equal Plan::STATUS_NO_RELATION, plan.planners.find(user_with_contacts.planner.id).cal_pln_status.to_i
  end
end
