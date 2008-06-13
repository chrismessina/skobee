require File.dirname(__FILE__) + '/../test_helper'
require 'planners_controller'

# Re-raise errors caught by the controller.
class PlannersController; def rescue_action(e) raise e end; end

class PlannersControllerTest < Test::Unit::TestCase

  fixtures :planners, :plans, :users, :planners_plans, :user_contacts, :places, :emails, :plan_changes, :zipcodes, :offsets_timezones

  def setup
    @controller = PlannersController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  #KS- make sure users can set different attributes to private
  def test_ok_to_show_att
    #KS- set all of existingbob's settings to most public
    existingbob = users(:existingbob)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_ZIP_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_MOBILE_PHONE_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_GENDER_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_REAL_NAME_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_EMAIL_SECURITY_GROUP)

    #KS- edit existingbob's profile so that he has some stuff on it
    login('existingbob', 'atest')
    get_to_controller(PlannersController.new, 'show', { :id => 1 })
    post_to_controller(UsersController.new, 'edit_profile',
      {
        "user_atts" => { "#{UserAttribute::ATT_BIRTH_YEAR}" => (Time.now.year - 62).to_s,
                         "#{UserAttribute::ATT_GENDER}" => UserAttribute::GENDER_FEMALE.to_s,
                         "#{UserAttribute::ATT_RELATIONSHIP_STATUS}" => UserAttribute::RELATIONSHIP_TYPE_TAKEN.to_s,
                       },
        'user' => { "real_name" => "asdf fdsa", "description" => "my description", "zipcode" => "94103" }
      })

    #KS- login as bob and view user 2's profile
    logout
    login
    get :show, :id => 2

    #KS- should be able to see age, gender, relationship status, and description for now
    assert_tag :tag => 'dt', :content => 'Gender'
    assert_tag :tag => 'dd', :content => 'female'
    assert_tag :tag => 'dt', :content => 'Are They Single?'
    assert_tag :tag => 'dd', :content => 'no'
    assert_tag :tag => 'dt', :content => 'Age'
    assert_tag :tag => 'dd', :content => '62'
    assert_tag :tag => 'dt', :content => 'Description'
    assert_tag :tag => 'dd', :content => 'my description'

    user = users(:existingbob)

    #KS- set everything to the most private settings so that it all gets censored
    user.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_ZIP_SECURITY_GROUP)
    user.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_MOBILE_PHONE_SECURITY_GROUP)
    user.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP)
    user.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_GENDER_SECURITY_GROUP)
    user.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP)
    user.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP)
    user.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_REAL_NAME_SECURITY_GROUP)
    user.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_EMAIL_SECURITY_GROUP)
    user.save!

    #KS- login as bob and view user 2's profile
    login
    get :show, :id => 2
    assert_tag :tag => 'h2', :content => "existingbob's Plans"

    #KS- shouldn't be able to see age, gender, relationship status, or description
    assert_no_tag :tag => 'dt', :content => 'Gender'
    assert_no_tag :tag => 'dd', :content => 'male'
    assert_no_tag :tag => 'dt', :content => 'Are They Single?'
    assert_no_tag :tag => 'dd', :content => 'yes'
    assert_no_tag :tag => 'dt', :content => 'Age'
    assert_no_tag :tag => 'dd', :content => '26'
    assert_no_tag :tag => 'dt', :content => 'Description'
    assert_no_tag :tag => 'dd', :content => 'my description'
  end

  def test_require_login
    #MES- All pages should require login

    #MES- Make sure we're not logged in
    logout

		#MES- Show does NOT require login (anymore)!
    get :show, :id => planners(:first_planner).id
    assert_success

    get :edit, :id => planners(:first_planner).id
    assert_redirect_to_login

    post :update, :id => planners(:first_planner).id, 'planner' => { 'name' => 'new name' }
    assert_redirect_to_login

    get :accept_plan, :id => planners(:first_planner).id, :pln_id => plans(:first_plan).id
    assert_redirect_to_login

    get :reject_plan, :id => planners(:first_planner).id, :pln_id => plans(:first_plan).id
    assert_redirect_to_login
  end

  def test_show
    login

    get :show, :id => planners(:existingbob_planner).id
    assert_response :success, 'Showing a planner while logged in failed'
    assert_template 'show', 'The "show" template was not used while showing a planner'
    assert_valid_markup
    
    #MES- Same thing should work when passing in user login for the id
    login_str = planners(:existingbob_planner).owner.login
    get :show, :id => login_str
    assert_response :success, 'Showing a planner while logged in failed'
    assert_template 'show', 'The "show" template was not used while showing a planner'
    assert_valid_markup
    page_desc_str = "#{Inflector.possessiveize(login_str)} Plans"
    assert_tag :tag => 'h2', :content => /#{page_desc_str}/

    #MGS- check the validity of this page
    assert_tag :tag => 'h4', :content => /existing bob test plan/
    #MGS- friend_2_of user is a friend
    assert_tag :tag => 'ul', :content => /friend_2_of_user/

    get :show, :user_id => users(:existingbob).id
    assert_response :success, 'Showing a planner while logged in failed'
    assert_template 'show', 'The "show" template was not used while showing a planner'
    assert_valid_markup

    login users(:contact_1_of_user)
    get :plans_history
    assert_response :success, 'Showing a planner while logged in failed'
    assert_template 'plans_history', 'The "plans_history" template was not used while showing a planner'
    assert_valid_markup

    #MGS- should only see Add Comment link when you have been set as a friend or a contact of the user
    get :show, :id => planners(:existingbob_planner).id
    assert_success
    assert_no_tag :tag => "a", :content => "Add Comment"

    #MGS- add bob as a contact of existing bob
    users(:existingbob).add_or_update_contact(users(:bob), { :friend_status => User::FRIEND_STATUS_CONTACT })
    login
    get :show, :id => planners(:existingbob_planner).id
    assert_success
    assert_tag :tag => "a", :content => "Add Comment", :attributes => { :id => "add-comment" }

    #MGS- add bob as a friend of existing bob
    users(:existingbob).add_or_update_contact(users(:bob), { :friend_status => User::FRIEND_STATUS_FRIEND })
    login
    get :show, :id => planners(:existingbob_planner).id
    assert_success
    assert_tag :tag => "a", :content => "Add Comment", :attributes => { :id => "add-comment" }

    #MGS- remove relationship
    users(:existingbob).add_or_update_contact(users(:bob), { :friend_status => User::FRIEND_STATUS_NONE })
    login
    get :show, :id => planners(:existingbob_planner).id
    assert_success
    assert_no_tag :tag => "a", :content => "Add Comment"
  end
  
  def test_show_not_authenticated
  	logout
  	#MES- Planners should be visible even when not logged in, though the level
  	#	of details that are visible should be determined by the planner settings for strangers.
  	
    get :show, :id => planners(:existingbob_planner).id
    assert_response :success, 'Showing a planner while logged in failed'
    assert_template 'show', 'The "show" template was not used while showing a planner'
    assert_valid_markup

    #MGS- check the validity of this page
    assert_tag :tag => 'h4', :content => /existing bob test plan/
    #MGS- friend_2_of user is a friend
    assert_tag :tag => 'ul', :content => /friend_2_of_user/
    
    #MES- Should not see the Add Comment link
    get :show, :id => planners(:existingbob_planner).id
    assert_success
    assert_no_tag :tag => "a", :content => "Add Comment"
  end

  def test_accept
    login users(:existingbob)

    #MGS- test the accept when already on a plan
    assert plans(:another_plan).planners.include?(planners(:existingbob_planner))
    get :schedule_details, :id=> planners(:existingbob_planner).id
    post :accept_plan, {:id => planners(:existingbob_planner).id, :pln_id => plans(:another_plan).id}
    assert_redirected_to("/plans/show/#{plans(:another_plan).id}?cal_id=#{planners(:existingbob_planner).id}", 'Accepting a plan while logged in did not redirect to "plan details"')

    #MGS- test the accept when not already on a plan
    assert !plans(:another_plan).planners.include?(planners(:contact_2_of_user_planner))
    get :schedule_details, :id=> planners(:contact_2_of_user_planner).id
    #MGS- assert that an error was raised
    assert_raise(RuntimeError) {post :accept_plan, {:id => planners(:contact_2_of_user_planner).id, :pln_id => plans(:another_plan).id}}
    #MGS- and assert that the planner wasn't added to the plan
    assert !plans(:another_plan).planners.include?(planners(:contact_2_of_user_planner))
  end

  def test_interested
    login users(:existingbob)

    #MES- test the interested when already on a plan
    assert plans(:another_plan).planners.include?(planners(:existingbob_planner))
    get :schedule_details, :id=> planners(:existingbob_planner).id
    post :express_interest_in_plan, {:id => planners(:existingbob_planner).id, :pln_id => plans(:another_plan).id}
    assert_redirected_to("/plans/show/#{plans(:another_plan).id}?cal_id=#{planners(:existingbob_planner).id}", 'Expressing interest in a plan while logged in did not redirect to "plan details"')
    assert_equal Plan::STATUS_INTERESTED, users(:existingbob).planner.plans(true).detect{|x| x.id == plans(:another_plan).id}.cal_pln_status.to_i

    #MES- test the interest when not already on a plan
    assert !plans(:another_plan).planners.include?(planners(:contact_2_of_user_planner))
    get :schedule_details, :id=> planners(:contact_2_of_user_planner).id
    #MGS- assert that an error was raised
    assert_raise(RuntimeError) {post :express_interest_in_plan, {:id => planners(:contact_2_of_user_planner).id, :pln_id => plans(:another_plan).id}}
    #MGS- and assert that the planner wasn't added to the plan
    assert !plans(:another_plan).planners.include?(planners(:contact_2_of_user_planner))
  end

  def test_reject
    login users(:existingbob)

    get :dashboard
    #MGS- test the reject when already on a plan
    assert plans(:another_plan).planners.include?(planners(:existingbob_planner))
    post :reject_plan, {:id => planners(:existingbob_planner).id, :pln_id => plans(:another_plan).id}
    assert_redirected_to("/planners/dashboard", 'Rejecting a plan while logged in did not redirect to "dashboard"')

    #MGS- test the reject when not already on a plan
    assert !plans(:another_plan).planners.include?(planners(:contact_2_of_user_planner))
    get :schedule_details, :id=> planners(:contact_2_of_user_planner).id
    #MGS- assert that an error was raised
    assert_raise(RuntimeError) {post :reject_plan, {:id => planners(:contact_2_of_user_planner).id, :pln_id => plans(:another_plan).id}}
    #MGS- and assert that the planner wasn't added to the plan
    assert !plans(:another_plan).planners.include?(planners(:contact_2_of_user_planner))
  end
  
  def test_status_change_conditional_login
  	#MES- Make sure we're not logged in
  	logout
  	
  	usr = users(:existingbob)
  	plnr = planners(:existingbob_planner)
  	pln = plans(:another_plan)
  	
    qsmap = UserNotify.conditional_login_querystring(usr, [UserNotify.conditional_item_for_plan(pln.id)]).querystring_to_map
    
    qsmap['id'] = plnr.id
    qsmap['pln_id'] = pln.id
    
    #MES- Change the status in various ways
    post :accept_plan, qsmap
    #MES- We'll be redirected to the details of the plan
    assert_redirected_to :controller => 'plans', :id => pln.id, :cal_id => plnr.id.to_s, :action => 'show'
    #MES- And it should be accepted
    assert_equal Plan::STATUS_ACCEPTED, plnr.plans(true).detect{ |p| p.id == pln.id}.cal_pln_status.to_i
    
    #MES- For subsequent status changes, we shouldn't have to pass in the conditional login info, because
    #	we should be conditionally logged in already
    post :express_interest_in_plan, :id => plnr.id, :pln_id => pln.id
    assert_redirected_to :controller => 'plans', :id => pln.id, :cal_id => plnr.id.to_s, :action => 'show'
    assert_equal Plan::STATUS_INTERESTED, plnr.plans(true).detect{ |p| p.id == pln.id}.cal_pln_status.to_i
    	
    post :reject_plan, :id => plnr.id, :pln_id => pln.id
    #MES- When rejecting a plan, we're redirected to the planner, not the plan, since it's a "redirect_back"
    assert_redirected_to :controller => 'planners', :action => 'schedule_details'
    assert_equal Plan::STATUS_REJECTED, plnr.plans(true).detect{ |p| p.id == pln.id}.cal_pln_status.to_i
    
    #MES- We should NOT be able to use the conditional login to change the status of OTHER plans,
    #	since it's attached to that particular plan.
    pln = plans(:plan_for_existingbob)
    post :express_interest_in_plan, :id => plnr.id, :pln_id => pln.id
    assert_redirect :controller => 'users', :action => 'login'
    assert_equal Plan::STATUS_ACCEPTED, plnr.plans(true).detect{ |p| p.id == pln.id}.cal_pln_status.to_i
    post :reject_plan, :id => plnr.id, :pln_id => pln.id
    assert_redirect :controller => 'users', :action => 'login'
    assert_equal Plan::STATUS_ACCEPTED, plnr.plans(true).detect{ |p| p.id == pln.id}.cal_pln_status.to_i
    post :accept_plan, :id => plnr.id, :pln_id => pln.id
    assert_redirect :controller => 'users', :action => 'login'
    assert_equal Plan::STATUS_ACCEPTED, plnr.plans(true).detect{ |p| p.id == pln.id}.cal_pln_status.to_i    
  end

  def test_view_other_user

    #MES- The owner should get the 'owner' view of a public planner
    login users(:user_with_friends)
    get :show, :id => users(:friend_1_of_user).planner.id
    assert_response :success, 'Showing a planner while logged in failed'
    assert_template 'show', 'The "show" template was not used while showing a planner'
    #MES- Check what subview we got by looking for a tag
    assert_tag :tag => 'span', :attributes => { :id => 'show_plan_details' }
    assert_valid_markup

    #MES- A friend should get the "details" view of a public planner
    login users(:friend_1_of_user)
    get :show, :id => users(:user_with_friends).planner.id
    assert_response :success, 'Showing a planner while logged in failed'
    assert_template 'show', 'The "show" template was not used while showing a planner'
    #MES- Check what subview we got by looking for a tag
    assert_tag :tag => 'span', :attributes => { :id => 'show_plan_details' }
    assert_valid_markup

    #MES- A stranger should get the 'plans' view of a public planner
    login users(:not_a_friend)
    get :show, :id => users(:user_with_friends).planner.id
    assert_response :success, 'Showing a planner while logged in failed'
    assert_template 'show', 'The "show" template was not used while showing a planner'
    #MES- Check what subview we got by looking for a tag
    assert_tag :tag => 'span', :attributes => { :id => 'show_plan_details' }
    assert_valid_markup

    #MES- A friend should get the "details" view of a friends planner
    login users(:friend_1_of_user)
    get :show, :id => users(:user_with_friends_and_friends_cal).planner.id
    assert_response :success, 'Showing a planner while logged in failed'
    assert_template 'show', 'The "show" template was not used while showing a planner'
    #MES- Check what subview we got by looking for a tag
    assert_tag :tag => 'span', :attributes => { :id => 'show_plan_details' }
    assert_valid_markup

    #MES- A stranger should get the 'availability' view of a friends planner
    login users(:not_a_friend)
    get :show, :id => users(:user_with_friends_and_friends_cal).planner.id
    assert_response :success, 'Showing a planner while logged in failed'
    assert_template 'show', 'The "show" template was not used while showing a planner'
    #MGS- we are no longer displaying the plans if the availability view is shown
    assert_no_tag :tag => 'div', :content => /plan-list/
    assert_valid_markup

    #MES- A friend should get the 'availability' view of a private planner
    login users(:friend_1_of_user)
    get :show, :id => users(:user_with_friends_and_private_cal).planner.id
    assert_response :success, 'Showing a planner while logged in failed'
    assert_template 'show', 'The "show" template was not used while showing a planner'
    #MGS- we are no longer displaying the plans if the availability view is shown
    assert_no_tag :tag => 'div', :content => /plan-list/
    assert_valid_markup

    #MES- A stranger should get the 'availability' view of a private planner
    login users(:not_a_friend)
    get :show, :id => users(:user_with_friends_and_private_cal).planner.id
    assert_response :success, 'Showing a planner while logged in failed'
    assert_template 'show', 'The "show" template was not used while showing a planner'
    #MGS- we are no longer displaying the plans if the availability view is shown
    assert_no_tag :tag => 'div', :content => /plan-list/
    assert_valid_markup
  end

  def test_schedule_details
    login users(:user_with_contacts)

    #MES- When you try to see the schedule details of ANOTHER user, you should see
    #  the 'show' template
    get :schedule_details, :id => planners(:contact_1_of_user_planner).id
    #MES- TODO: Why is the "to_s" needed here?  Is this a bug in
    #  assert_redirected_to?
    assert_redirected_to :id => planners(:contact_1_of_user_planner).id.to_s, :action => 'show'

    #MES- You should be able to see your own schedule details
    current_user = users(:user_with_contacts)
    get :schedule_details, :id => current_user.planner.id
    assert_template 'schedule_details', 'Viewing your own schedule details should use the \'schedule_details\' template'

    #MES- The user should have a contact (contact_1_of_user), look for it
    #MES- For convenience, we made the name of the user a GUID, so we can find the string easily
    #  and deterministically.
    #MGS- now that this string is being truncated, just search for the first part
    assert_tag :tag => 'td', :content => /98BC6156A06A40ec8/

    #MES- The recent places that friends have attended plans should be displayed.
    #  Log in as the 'user_with_friends' user and check that we can see recent places.
    login users(:user_with_friends)
    current_user = users(:user_with_friends)
    get :schedule_details, :id => current_user.planner.id
    assert_tag :tag => 'dt', :content => '2F21F2C994EE48908B4704550961E7A7'
    assert_tag :tag => 'dt', :content => 'E37B08B1454846E8A1895F5C6E03F22F'

    assert_valid_markup

    #MES- TODO: Eventually, we should write tests that check that the rest of the HTML
    #  stuff is right (that private planners are displayed correctly, etc.)  However,
    #  since the HTML is likely to change a lot in the near future (it's 9/22/05 now),
    #  that seems not so useful.

  end


  def test_dashboard
    #MGS-placeholder for dashboard functional tests
    login users(:user_with_friends)
    get :dashboard
    assert_valid_markup

    login users(:user_with_contacts)
    get :dashboard
    assert_valid_markup

    #MGS- test new invites
    assert_tag :tag => 'span', :content => /solid_plan_in_expiry/

    #MGS- test upcoming plans
    assert_tag :tag => 'span', :content => /future plan for exist/
    assert_tag :tag => 'span', :content => /plan for place stats/
    assert_tag :tag => 'span', :content => /second plan for place/

    #MGS- make a place change that will show up on the dashboard for contact_1_of_user
    plan = plans(:second_plan_for_place_stats)
    plan.checkpoint_for_revert(users(:friend_1_of_user))
    plan.place = places(:another_place)
    plan.save

    #MGS- make a time change that will show up on the dashboard for contact_1_of_user
    plan = plans(:second_plan_for_place_stats)
    plan.checkpoint_for_revert(users(:friend_1_of_user))
    plan.set_datetime(TZInfo::Timezone.get('America/Tijuana'), Plan::DATE_DESCRIPTION_NEXT_WEEKEND, Plan::TIME_DESCRIPTION_BREAKFAST)
    plan.save

    login users(:contact_1_of_user)
    get :dashboard
    assert_valid_markup

    #MGS- test plans a changin
    assert_tag :tag => 'h4', :content => /friend_1_of_user - second plan/, :attributes => {:class => 'title'}, :ancestor => {:tag => "div", :attributes => { :class => "comment time_change" }}
    assert_tag :tag => 'h4', :content => /suggested: Some day next We/, :attributes => {:class => 'change'}, :ancestor => {:tag => "div", :attributes => { :class => "comment time_change" }}

    assert_tag :tag => 'h4', :content => /friend_1_of_user - second plan/, :attributes => {:class => 'title'}, :ancestor => {:tag => "div", :attributes => { :class => "comment place_change" }}
    assert_tag :tag => 'h4', :content => /suggested: E37B08B1454846E8/, :attributes => {:class => 'change'}, :ancestor => {:tag => "div", :attributes => { :class => "comment place_change" }}

    assert_tag :tag => 'h4', :content => /user_with_contacts - second pl/, :attributes => {:class => 'title'}, :ancestor => {:tag => "div", :attributes => { :class => "comment place_change" }}
    assert_tag :tag => 'p', :content => /I\'m OK with Triptych, but how about Julie\'s?/, :ancestor => {:tag => "div", :attributes => { :class => "comment place_change" }}

    assert_tag :tag => 'h4', :content => /user_with_contacts - second pl/, :attributes => {:class => 'title'}, :ancestor => {:tag => "div", :attributes => { :class => "comment time_change" }}
    assert_tag :tag => 'p', :content => /Another comment/, :ancestor => {:tag => "div", :attributes => { :class => "comment time_change" }}

    assert_tag :tag => 'h4', :content => /user_with_contacts - second pl/, :attributes => {:class => 'title'}, :ancestor => {:tag => "div", :attributes => { :class => "comment comment_change" }}
    assert_tag :tag => 'p', :content => /Another comment/, :ancestor => {:tag => "div", :attributes => { :class => "comment comment_change" }}
  end

  def test_security
    #MES- Make sure that for each method, we can only use it
    #  if we're the correct user (the user that owns the planner.)
    login

    #MES- All users can see all planners through "show", so we
    #  won't test "show"
    assert_raise(RuntimeError) { get :accept_plan, :id => 2, :pln_id => 1 }
    assert_raise(RuntimeError) { get :reject_plan, :id => 2, :pln_id => 1 }
  end

  def test_people_clipboard
    #MGS- testing adding,selecting,and removing a clipboard user
    login users(:contact_1_of_user)

    #test add to clipboard
    get :add_contact_to_clipboard_ajax, :contact_id => "#{users(:user_with_contacts).login} (#{users(:user_with_contacts).full_name})"
    assert_response :success, 'Adding contact to clipboard failed'
    assert_tag :tag => 'td', :content => "#{users(:user_with_contacts).full_name}", :attributes => {:id => "contact_name_#{users(:user_with_contacts).id}"}

    #reload the schedule details page to make sure the user was really added to the clipboard
    get :schedule_details
    assert_response :success, 'Refreshing the schedule details page failed'
    assert_tag :tag => 'td', :content => "#{users(:user_with_contacts).full_name}", :attributes => {:id => "contact_name_#{users(:user_with_contacts).id}"}

    #test selecting contact
    get :edit_clipboard_status_ajax, {:contact_id => "#{users(:user_with_contacts).id}", :status => "true"}
    assert_response :success, 'Selecting a clipboard user failed'
    #MGS- since the response of this is the schedule details body, not much we can really check for

    #reload the schedule details page to make sure the user is really checked on the clipboard
    get :schedule_details
    assert_response :success, 'Refreshing the schedule details page failed'
    assert_tag :tag => 'td', :content => "#{users(:user_with_contacts).full_name}", :attributes => {:id => "contact_name_#{users(:user_with_contacts).id}"}

    #remove this contact from the clipboard
    post :remove_contact_from_clipboard_ajax, :contact_id => "#{users(:user_with_contacts).id}", :refresh => "true"
    assert_response :success, 'Removing a contact from the people clipboard failed.'


    #reload the schedule details page to make sure the user is really removed from the clipboard
    get :schedule_details
    assert_response :success, 'Refreshing the schedule details page failed'
    #MGS- since the user has been removed, these tags should not be in the html
    assert_no_tag :tag => 'td', :content => "#{users(:user_with_contacts).full_name}", :attributes => {:id => "contact_name_#{users(:user_with_contacts).id}"}
  end

  def test_unregistered_user
    login
    #MGS- view the unregistered user's profile; we should see a flash with a link to invite
    get :show, :id => users(:unregistered_user).id
    assert_success
    assert_valid_markup
    assert_tag :tag => 'div', :content => /is already using Skobee, but hasn't signed up yet\./
    #MGS- make sure it also includes an invite link in the flash
    assert_tag :tag => 'a', :attributes => { :href => /\/users\/invite\//}
  end

  def test_planner_display_times
    #MGS- This test looks on several different planner pages and looks for plans
    # that are right on the edge of being in the today/yesterday split for their local
    # timezone

    #MGS- test the schedule details page
    login('not_a_friend', 'atest')
    get :schedule_details, :id => users(:not_a_friend).id
    assert_success
    assert_tag :tag => 'div', :content => plans(:plan_today_all_day).name
    assert_tag :tag => 'div', :content => plans(:plan_today_but_barely).name
    assert_no_tag :tag => 'div', :content => plans(:planner_past_plan_1).name
    assert_no_tag :tag => 'div', :content => plans(:plan_yesterday_but_barely).name

    #MGS- test the plan history page
    login('not_a_friend', 'atest')
    get :plans_history
    assert_success
    assert_tag :tag => 'div', :content => plans(:planner_past_plan_1).name
    assert_tag :tag => 'div', :content => plans(:plan_yesterday_but_barely).name
    assert_no_tag :tag => 'div', :content => plans(:plan_today_all_day).name
    assert_no_tag :tag => 'div', :content => plans(:plan_today_but_barely).name

    #MGS- test the dashboard page
    login('not_a_friend', 'atest')
    get :dashboard
    assert_success
    assert_no_tag :tag => 'div', :content => plans(:planner_past_plan_1).name
    assert_no_tag :tag => 'div', :content => plans(:plan_yesterday_but_barely).name
    assert_tag :tag => 'div', :content => plans(:plan_today_all_day).name
    assert_tag :tag => 'div', :content => plans(:plan_today_but_barely).name

    #MGS- test the planner/show page for the current user
    login('not_a_friend', 'atest')
    get :show, :id => users(:not_a_friend).id
    assert_success
    assert_no_tag :tag => 'div', :content => plans(:planner_past_plan_1).name
    assert_no_tag :tag => 'div', :content => plans(:plan_yesterday_but_barely).name
    assert_tag :tag => 'div', :content => plans(:plan_today_all_day).name
    assert_tag :tag => 'div', :content => plans(:plan_today_but_barely).name
  end

  def test_comments
    login
    get :show, :id => planners(:existingbob_planner).id

    #add comment
    post :add_comment_ajax, :user_id => users(:existingbob).id, :comment_tb => "this is a new comment"

    assert_success
    assert_tag :tag=>"p", :content => "this is a new comment"

    user = assigns(:user)
    comments = user.comments
    #MGS- we can do this because this should be the only comment
    assert_equal 1, comments.length
    comment_id = comments[0].id

    #edit comment
    post :edit_comment_ajax, :comment_id=> comment_id, :user_id => users(:existingbob).id, "comment_edit_tb#{comment_id}" => "this is the edited comment"

    assert_success
    assert_tag :tag=>"p", :content => "this is the edited comment"

    #delete comment
    post :delete_comment_ajax, :comment_id=> comment_id, :user_id => users(:existingbob).id

    user = users(:existingbob)
    comments = user.comments
    #MGS- the comment should have been deleted
    assert comments.length == 0


    get :show, :id=> users(:existingbob).id
    assert_success
    assert_valid_markup


    #MGS- test truncating a long comment
    #add comment
    post :add_comment_ajax, :user_id => users(:existingbob).id, :comment_tb => "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Duis aliquam nisl ullamcorper est. Quisque in dui viverra enim mattis lobortis. Praesent sit amet augue id enim volutpat posuere. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Donec condimentum lacus eget arcu. Suspendisse et velit. Vestibulum a ante a neque tristique vehicula. Sed laoreet, ligula nec imperdiet mattis, pede felis dapibus mauris, sit amet vestibulum lorem elit dapibus tellus. Vivamus vel massa. Ut sagittis, ligula vel laoreet placerat, mi velit dapibus est, vitae dapibus purus nibh vitae nunc. Praesent sit amet lectus. Mauris suscipit mi vel mi faucibus pellentesque. Phasellus sodales rutrum magna. Duis imperdiet dolor sit amet nisl. Etiam magna. Pellentesque molestie venenatis ante. Nullam tellus elit, volutpat eget, elementum eu, rutrum tempus, arcu. Nulla arcu augue, sodales vel, gravida id, viverra nec, magna.Maecenas adipiscing diam vel metus. Aenean risus ipsum, pulvinar in, bibendum vel, auctor ac, tellus. Fusce non ligula nec massa consequat egestas. Etiam bibendum. In hac habitasse platea dictumst. Donec id odio. Curabitur pretium dolor eu leo. Vivamus ornare. Curabitur velit pede, gravida porttitor, malesuada mattis, molestie sit amet, risus. In a orci eu lectus dapibus aliquam. Curabitur faucibus nunc. Donec diam. Sed pede. Praesent a nulla. Praesent pretium. Aenean vestibulum.Integer sagittis neque a mi. Ut commodo blandit odio. Nam augue augue, egestas sit amet, consectetuer in, faucibus at, pede. Praesent a pede eget sem sollicitudin lobortis. Maecenas semper. Praesent tincidunt vestibulum justo. Cras sit amet odio ac urna blandit consequat. Etiam id lorem nec quam lacinia vehicula. Suspendisse consequat faucibus mauris. Aliquam dapibus. Praesent commodo. Proin ultrices, ligula sed iaculis pretium, erat turpis pellentesque velit, eget pretium lorem arcu sit amet felis. Suspendisse potenti.Quisque faucibus pede at enim tincidunt bibendum. Curabitur eu nibh. Aliquam lobortis arcu eu libero. Donec nibh metus, mollis eget, ultrices at, lacinia ut, urna. Sed sollicitudin blandit tellus. Praesent lectus. Cras quis diam. Aliquam massa turpis, adipiscing ac, porttitor a, suscipit et, elit. In hac habitasse platea dictumst. Suspendisse erat odio, dignissim non, rutrum id, sodales vel, elit. Mauris in tortor. Cras in orci ac lectus vestibulum varius. Quisque dignissim sem in massa. Suspendisse turpis sapien, auctor a, cursus a, blandit eu, leo. Mauris vel est. Mauris ultricies dolor varius sem. Sed euismod est vitae velit. Suspendisse luctus auctor mauris.Ut volutpat, arcu nec blandit tristique, sapien justo venenatis odio, vel suscipit ipsum mauris sit amet lacus. Vestibulum felis lacus, vestibulum et, vulputate a, semper eget, magna. Sed convallis luctus diam. Sed feugiat ante blandit neque. Donec sed metus in arcu consequat convallis. Nam volutpat. Ut ante ipsum, fermentum eu, faucibus aliquet, accumsan at, velit. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Nulla facilisi. Nullam elit sapien, rhoncus in, vulputate eget, pharetra ac, elit. Praesent eget orci. Etiam lacus. Ut feugiat enim ac orci. Aenean vitae leo sed lorem imperdiet tempus. Mauris est arcu, hendrerit sit amet, viverra non, volutpat sit amet, erat. Cras porta, orci ac hendrerit convallis, est lorem volutpat velit, eget aliquam quam orci tincidunt dolor.Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Vestibulum ligula purus, ullamcorper at, ultricies placerat, ultricies vitae, lorem. Proin euismod. Maecenas semper enim ultrices neque. Quisque consequat augue eu eros. Pellentesque libero. Cras accumsan. Fusce ut magna. Suspendisse porttitor fringilla metus. Duis felis. Cras pretium orci nec nulla. Etiam fringilla dictum magna. In adipiscing porta tellus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Ut ligula eros, imperdiet feugiat, porttitor ut, convallis ac, ligula. Sed leo arcu, iaculis non, auctor id, luctus eu, sem. Cras et ligula et massa luctus luctus. In hac habitasse platea dictumst. Donec nonummy.Donec quis tortor. Aenean lobortis leo et nisl. Ut volutpat rutrum sapien. In dolor orci, viverra eu, sagittis in, rhoncus eget, mauris. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Fusce eget enim quis risus ornare molestie. Nulla ut est. Maecenas massa urna, porta sit amet, euismod sit amet, lacinia in, tortor. Nunc convallis condimentum nisl. Donec est. Nunc condimentum ipsum gravida nunc. Nulla interdum semper lacus. Vivamus odio turpis, malesuada in, imperdiet nec, aliquam elementum, erat. Phasellus adipiscing condimentum ligula. Quisque rutrum massa non neque. Donec laoreet diam ut leo. Suspendisse dui erat, egestas a, feugiat quis, pharetra vitae, ipsum. Nulla convallis dolor a purus. Sed felis magna, auctor id, pretium et, lobortis rutrum, nibh. Suspendisse massa nunc."
    assert_success
    assert_tag :tag=>"p", :content => "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Duis aliquam nisl ullamcorper est. Quisque in dui viverra enim mattis lobortis. Praesent sit amet augue id enim volutpat posuere. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Donec condimentum lacus eget arcu. Suspendisse et velit. Vestibulum a ante a neque tristique vehicula. Sed laoreet, ligula nec imperdiet mattis, pede felis dapibus mauris, sit amet vestibulum lorem elit dapibus tellus. Vivamus vel massa. Ut sagittis, ligula vel laoreet placerat, mi velit dapibus est, vitae dapibus purus nibh vitae nunc. Praesent sit amet lectus. Mauris suscipit mi vel mi faucibus pellentesque. Phasellus sodales rutrum magna. Duis imperdiet dolor sit amet nisl. Etiam magna. Pellentesque molestie venenatis ante. Nullam tellus elit, volutpat eget, elementum eu, rutrum tempus, arcu. Nulla arcu augue, sodales vel, gravida id, viverra nec, magna.Maecenas adipiscing diam vel metus. Aenean risus ipsum, pulvinar in, bibendum vel, auctor ac, tellus. Fusce non ligula nec massa consequat egestas. Etiam bibendum. In hac habitasse platea dictumst. Donec id odio. Curabitur pretium dolor eu leo. Vivamus ornare. Curabitur velit pede, gravida porttitor, malesuada mattis, molestie sit amet, risus. In a orci eu lectus dapibus aliquam. Curabitur faucibus nunc. Donec diam. Sed pede. Praesent a nulla. Praesent pretium. Aenean vestibulum.Integer sagittis neque a mi. Ut commodo blandit odio. Nam augue augue, egestas sit amet, consectetuer in, faucibus at, pede. Praesent a pede eget sem sollicitudin lobortis. Maecenas semper. Praesent tincidunt vestibulum justo. Cras sit amet odio ac urna blandit consequat. Etiam id lorem nec quam lacinia vehicula. Suspendisse consequat faucibus mauris. Aliquam dapibus. Praesent commodo. Proin ultrices, ligula sed iaculis pretium, erat turpis pellentesque velit, eget pretium lorem arcu sit amet felis. Suspendisse potenti.Quisque faucibus pede at enim tincidunt bibendum. Curabitur eu nibh. Aliquam lobortis arcu eu libero. Donec nibh metus, mollis eget, ultrices at, lacinia ut, urna. Sed sollicitudin blandit tellus. Praesent lectus. Cras quis diam. Aliquam massa turpis, adipiscing ac, porttitor a, suscipit et, elit. In hac habitasse platea dictumst. Suspendisse erat odio, dignissim non, rutrum id, sodales vel, elit. Mauris in tortor. Cras in orci ac lectus vestibulum varius. Quisque dignissim sem in massa. Suspendisse turpis sapien, auctor a, cursus a, blandit eu, leo. Mauris vel est. Mauris ultricies dolor varius sem. Sed euismod est vitae velit. Suspendisse luctus auctor mauris.Ut volutpat, arcu nec blandit tristique, sapien justo venenatis odio, vel suscipit ipsum mauris sit amet lacus. Vestibulum felis lacus, vestibulum et, vulputate a, semper eget, magna. Sed convallis luctus diam. Sed feugiat ante blandit neque. Donec sed metus in arcu consequat convallis. Nam volutpat. Ut ante ipsum, fermentum eu, faucibus aliquet, accumsan at, velit. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Nulla facilisi. Nullam elit sapien, rhoncus in, vulputate eget, pharetra ac, elit. Praesent eget orci. Etiam lacus. Ut feugiat enim ac orci. Aenean vitae leo sed lorem imperdiet tempus. Mauris est arcu, hendrerit sit amet, viverra non, volutpat sit amet, erat. Cras porta, orci ac hendrerit convallis, est lorem volutpat velit, eget aliquam quam orci tincidunt dolor.Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Vestibulum ligula purus, ullamcorper at, ultricies placerat, ultricies vitae, lorem. Proin euismod. Maecenas semper enim ultrices neque. Quisque consequat augue eu eros. Pellentesque libero. Cras accumsan. Fusce ut magna. Suspendisse porttitor fringilla metus. Duis felis. Cras pretium orci nec nulla. Etiam fringilla dictum magna. In adipiscing porta tellus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Ut ligula eros, imperdiet feugiat, porttitor ut, convallis ac, ligula. Sed leo arcu, iaculis non, auctor id, luctus eu, sem. Cras et ligula et"

    get :show, :id=> users(:existingbob).id
    assert_success
    assert_valid_markup

    #MGS- No notifications should have happened
    assert_equal 0, @emails.length

    #MGS- login as bob, but post a comment on existingbobs profile; this should send an email
    # depending on existingbob's notification settings
    login users(:bob)
    #MGS- now enable user comment notifications
    users(:existingbob).set_att(UserAttribute::ATT_REMIND_BY_EMAIL, UserAttribute::TRUE_USER_ATT_VALUE)
    users(:existingbob).set_att(UserAttribute::ATT_USER_COMMENTED_NOTIFICATION_OPTION, UserAttribute::TRUE_USER_ATT_VALUE)
    #MGS- post another comment
    post :add_comment_ajax, :user_id => users(:existingbob).id, :comment_tb => "existingbob is a scrub"
    assert_equal 1, @emails.length

    assert_equal "Skobee - A comment on your profile", @emails[0].subject
    assert @emails[0].body.match(/existingbob is a scrub/)

    @emails.clear
    assert_equal 0, @emails.length
    #MGS- post a comment on your own profile, you shouldn't get a notification
    #MGS- now enable user comment notifications
    users(:bob).set_att(UserAttribute::ATT_REMIND_BY_EMAIL, UserAttribute::TRUE_USER_ATT_VALUE)
    users(:bob).set_att(UserAttribute::ATT_USER_COMMENTED_NOTIFICATION_OPTION, UserAttribute::TRUE_USER_ATT_VALUE)
    login users(:bob)
    #MGS- post comment
    post :add_comment_ajax, :user_id => users(:bob).id, :comment_tb => "I am scrub"
    assert_equal 0, @emails.length

    @emails.clear
    assert_equal 0, @emails.length
    #MGS- turn notifications off
    users(:existingbob).set_att(UserAttribute::ATT_USER_COMMENTED_NOTIFICATION_OPTION, UserAttribute::FALSE_USER_ATT_VALUE)
    #MGS- post another comemment
    post :add_comment_ajax, :user_id => users(:existingbob).id, :comment_tb => "yeti"
    assert_equal 0, @emails.length
  end

  def test_user_contacts
    login
    #MGS- should raise an error without an ID
    assert_raise(ActiveRecord::RecordNotFound) {get :user_contacts}

    get :user_contacts, :id => users(:user_with_friends).id
    assert_success
    assert_valid_markup
    assert_tag :tag => 'a', :content => 'existingbob'
  end
  
  def test_history_cancelled
    #MES- Test that cancelled plans show up on the plans history page
    login users(:existingbob)
    #MES- Test that we do NOT see the plan BEFORE cancelling it
    get :plans_history
    assert_success
    pln = plans(:plan_for_existingbob)
    assert_tag :tag => 'div', :content => "You don't have any canceled plans."
    assert_no_tag :tag => 'div', :content => pln.name
    #MES- Cancel it
    pln.cancel
    #MES- Log in again, to clear the cache of plan statuses
    login users(:existingbob)
    #MES- Test that we do see the plan after cancelling it
    get :plans_history
    assert_success
    assert_tag :tag => 'div', :content => pln.name
  end

end
