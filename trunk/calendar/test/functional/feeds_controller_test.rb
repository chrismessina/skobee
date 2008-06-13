require File.dirname(__FILE__) + '/../test_helper'
require 'feeds_controller'

module FeedTestHelper
  #MGS- mixed into the test classes
  def check_header(title, description, link)
    assert @response.body.match("<title>#{title}</title>")
    assert @response.body.match("<description>#{description}</description>")
    assert @response.body.match("<link>#{link}</link>")
  end

  def check_feed_item(title, pubdate, link, guid)
    assert @response.body.match("<title>#{title}</title>") unless title.blank?
    assert @response.body.match("<pubDate>#{pubdate}</pubDate>") unless pubdate.blank?
    assert @response.body.include?("<link>#{link}</link>") unless link.blank?
    assert @response.body.include?("<guid isPermaLink=\"false\">#{guid}</guid>") unless guid.blank?
  end
end

# Re-raise errors caught by the controller.
class FeedsController; def rescue_action(e) raise e end; end

class FeedsControllerTest_1 < Test::Unit::TestCase
  fixtures :users, :emails, :planners
  include FeedTestHelper

  def setup
    @controller = FeedsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_index
    #MGS- make sure you have to login to see this page
    get :index
    assert_redirect_to_login

    login
    get :index
    assert_success
    assert_template 'index'
    assert_valid_markup
  end


  def test_basic_authentication
    #MGS- test that basic auth works as advertised
    #MGS- while logged out, request an url that should be protected by
    # basic auth...passing in no credentials
    get :plan_changes, :id => users(:bob).id
    assert_equal "401", @response.headers['Status']
    assert_equal "Basic realm=\"#{UserSystem::CONFIG[:app_url]}\"", @response.headers['WWW-Authenticate']

    #MGS- if we're logged in, we shouldn't be prompted for basic auth
    login
    get :plan_changes, :id => users(:bob).id
    assert_success
    logout

    #MGS- pass valid credentials
    auth = users(:bob).login + ":atest"
    @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64(auth)}"
    get :plan_changes, :id => users(:bob).id
    assert_success
    assert_equal "application/xml; charset=utf-8", @response.headers['Content-Type']
  end
end

class FeedsControllerTest_2 < Test::Unit::TestCase
  fixtures :users, :emails, :planners, :plans, :planners_plans, :places, :plan_changes, :user_contacts, :user_atts
  include FeedTestHelper

  def setup
    @controller = FeedsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_plan_changes
    #MGS- test plan changes rss feed

    #MGS- pass valid credentials
    auth = users(:bob).login + ":atest"
    @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64(auth)}"
    get :plan_changes, :id => users(:bob).id
    assert_success
    assert_equal "application/xml; charset=utf-8", @response.headers['Content-Type']

    #MGS- now check that things are right in the xml
    # would be nice if assert_tag would work but it doesn't parse correctly
    check_header("Skobee: bob's plan changes", "A feed of bob's plan changes", "[^<]*/planners/dashboard")

    #MGS- bob doesn't have any items
    assert !@response.body.match("<item>")
    assert !@response.body.match("<pubDate>")

    #MGS- now as bob try and make a request for another user's feed; will get error
    get :plan_changes, :id => users(:existingbob).id
    assert_success
    check_header("Skobee: Error displaying feed", "Please check that the url to this feed is correct.", "[^<]*/feeds")
    assert !@response.body.match("<item>")

    #MGS- now as bob try and make a request a feed without and ID
    get :plan_changes
    assert_success
    check_header("Skobee: Error displaying feed", "Please check that the url to this feed is correct.", "[^<]*/feeds")
    assert !@response.body.match("<item>")

    #MGS- logout as bob
    logout

    #MGS- now log in as contact_1_of_user who has a bunch of plans a changin'
    auth = users(:contact_1_of_user).login + ":atest"
    @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64(auth)}"
    get :plan_changes, :id => users(:contact_1_of_user).id
    assert_success
    check_header("Skobee: contact_1_of_user's plan changes","A feed of contact_1_of_user's plan changes","[^<]*/planners/dashboard")

    #MGS- check for a couple of items
    change = plan_changes(:noaml_anniversary)
    assert @response.body.match("<item>")
    check_feed_item("user_with_contacts suggested James's restaurant - second plan for place stats", change.updated_at.rfc2822.to_s, @controller.url_for(:controller => 'plans', :action => 'show', :id => change.plan.id, :cal_id => change.owner.planner.id, :only_path => false), "uri://skobee.com/PlanChange/#{plan_changes(:noaml_anniversary).id}")
    assert @response.body.match("I'm OK with Triptych, but how about Julie's")

    #MGS- check that the right number of items are in the feed
    m = @response.body.scan(/<item>/)
    assert_equal 6, m.length
  end

  def test_user_feed
    #MGS- test viewing other peoples plan changes
    bob = users(:bob)
    user_with_contacts = users(:user_with_contacts)

    #MGS- Make a time change that will show up on the dashboard for user_with_contacts but
    # isn't a change that user_with_contacts made. This is easier than adding a new fixture
    # as doing that jacks all the other counts.
    plan = plans(:second_plan_for_place_stats)
    plan.checkpoint_for_revert(users(:friend_1_of_user))
    plan.set_datetime(TZInfo::Timezone.get('America/Tijuana'), Plan::DATE_DESCRIPTION_NEXT_WEEKEND, Plan::TIME_DESCRIPTION_BREAKFAST)
    plan.save

    #MGS- all requests need to have a planner id on the querystring
    get :user, :id => bob.id
    assert_success
    assert_equal 0, @response.body.scan(/<item>/).length
    check_header("Skobee: Error Displaying this user's plans", "The url requested appears incorrect.  Please try adding the feed again.", "[^<]*/feeds")

    #MGS- all requests need to have a user id on the querystring
    get :user, :planner_id => bob.planner.id
    assert_success
    assert_equal 0, @response.body.scan(/<item>/).length
    check_header("Skobee: Error Displaying this user's plans", "The url requested appears incorrect.  Please try adding the feed again.", "[^<]*/feeds")

    #MGS- check that you don't need security or even a logged in session to view a public planner
    get :user, :id => bob.id, :planner_id => user_with_contacts.planner.id
    assert_success
    assert_equal 6, @response.body.scan(/<item>/).length
    check_header("Skobee: user_with_contacts' plans", "A feed of user_with_contacts' plans", "[^<]*/planners/show/#{user_with_contacts.planner.id}")
    #MGS- check the contents of one of the items
    change = plan_changes(:noaml_anniversary)
    check_feed_item("user_with_contacts suggested James's restaurant - second plan for place stats", change.updated_at.rfc2822.to_s, @controller.url_for(:controller => 'plans', :action => 'show', :id => change.plan.id, :cal_id => change.owner.planner.id, :only_path => false), "uri://skobee.com/PlanChange/#{plan_changes(:noaml_anniversary).id}")

    #MGS- change the security of user_with_contacts_planner's planner to private
    planner = planners(:user_with_contacts_planner)
    planner.visibility_type = SkobeeConstants::PRIVACY_LEVEL_PRIVATE
    planner.save

    #MGS- now bob should be forced to login
    get :user, :id => bob.id, :planner_id => user_with_contacts.planner.id
    assert_equal "401", @response.headers['Status']
    assert_equal "Basic realm=\"#{UserSystem::CONFIG[:app_url]}\"", @response.headers['WWW-Authenticate']

    #MGS- try to log bob in the tradtional way in the UI first
    login
    get :user, :id => bob.id, :planner_id => user_with_contacts.planner.id
    assert_success
    #MGS- even though bob is logged in, he should see no plans of user_with_contacts as user_with_contacts has set his planner to private
    check_header("Skobee: Unable to display plan details", "This user may have recently changed plans security.", "[^<]*/feeds")
    assert_equal 0, @response.body.scan(/<item>/).length

    #MGS- now log out bob and login with the basic auth information instead of through the web ui
    logout
    #MGS- pass invalid basic auth credentials to make sure that still works
    auth = users(:bob).login + ":atevcst"
    @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64(auth)}"
    get :user, :id => bob.id, :planner_id => user_with_contacts.planner.id
    assert_equal "401", @response.headers['Status']

    auth = users(:bob).login + ":atest"
    @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64(auth)}"
    get :user, :id => bob.id, :planner_id => user_with_contacts.planner.id
    assert_success
    #MGS- even though bob is logged in, he should see no plans of user_with_contacts as user_with_contacts has set his planner to private
    check_header("Skobee: Unable to display plan details","This user may have recently changed plans security.", "[^<]*/feeds")
    assert_equal 0, @response.body.scan(/<item>/).length

    logout
    #MGS- even though the planner is private user_with_contacts should be able to see it
    auth = "user_with_contacts:atest"
    @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64(auth)}"
    get :user, :id => user_with_contacts.id, :planner_id => user_with_contacts.planner.id
    assert_success
    check_header("Skobee: user_with_contacts' plans", "A feed of user_with_contacts' plans", "[^<]*/planners/show/#{user_with_contacts.planner.id}")
    assert_equal 6, @response.body.scan(/<item>/).length
    #MGS- check the contents of one of the items
    change = plan_changes(:noaml_anniversary)
    check_feed_item("user_with_contacts suggested James's restaurant - second plan for place stats", change.updated_at.rfc2822.to_s, @controller.url_for(:controller => 'plans', :action => 'show', :id => change.plan.id, :cal_id => users(:user_with_contacts).planner.id, :only_path => false), "uri://skobee.com/PlanChange/#{plan_changes(:noaml_anniversary).id}")

    logout

    #MGS- now change exsiting bob's plannner visibility level to friends only
    planner = planners(:user_with_contacts_planner)
    planner.visibility_type = SkobeeConstants::PRIVACY_LEVEL_FRIENDS
    planner.save

    #MGS- bob should still get an error trying to view this planner as existing bob hasn't set bob as a friend
    auth = "bob:atest"
    @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64(auth)}"
    get :user, :id => bob.id, :planner_id => user_with_contacts.planner.id
    assert_success
    check_header("Skobee: Unable to display plan details","This user may have recently changed plans security.", "[^<]*/feeds")
    assert_equal 0, @response.body.scan(/<item>/).length
    logout

    #MGS- now set bob as a friend of existing bob
    user_with_contacts.add_or_update_contact(bob, { :friend_status => User::FRIEND_STATUS_FRIEND })
    auth = "bob:atest"
    @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64(auth)}"
    get :user, :id => bob.id, :planner_id => user_with_contacts.planner.id
    assert_success
    check_header("Skobee: user_with_contacts' plans", "A feed of user_with_contacts' plans", "[^<]*/planners/show/#{user_with_contacts.planner.id}")
    assert_equal 6, @response.body.scan(/<item>/).length
    #MGS- check the contents of one of the items
    change = plan_changes(:noaml_anniversary)
    check_feed_item("user_with_contacts suggested James's restaurant - second plan for place stats", change.updated_at.rfc2822.to_s, @controller.url_for(:controller => 'plans', :action => 'show', :id => change.plan.id, :cal_id => change.owner.planner.id, :only_path => false), "uri://skobee.com/PlanChange/#{plan_changes(:noaml_anniversary).id}")

    #MGS- as user_with_contacts, accept a plan so a RSVP comment is generated
    user_with_contacts.planner.accept_plan plans(:longbob_plan), user_with_contacts
    get :user, :id => bob.id, :planner_id => user_with_contacts.planner.id
    assert_success
    assert_equal 7, @response.body.scan(/<item>/).length
    check_feed_item("user_with_contacts RSVPed I'll Be There - 88D657E43CE549c48629EB777FC168A5", nil, @controller.url_for(:controller => 'plans', :action => 'show', :id => plans(:longbob_plan).id, :cal_id => user_with_contacts.planner.id, :only_path => false), nil)

  end

  def test_friends_plans
    #MGS- pass valid credentials
    bob = users(:bob)
    user_with_contacts = users(:user_with_contacts)
    auth = bob.login + ":atest"
    @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64(auth)}"
    get :friends_plans, :id => bob.id
    assert_success
    assert_equal "application/xml; charset=utf-8", @response.headers['Content-Type']

    #MGS- bob has no friends, so he shouldn't see anything here
    # but the title of the feed should still be in here
    check_header("Skobee: bob's friends plans","A feed of bob's friends plans","[^<]*/users/contacts")

    #MGS- bob has no friends, thus he has no plans
    m = @response.body.scan(/<item>/)
    assert_equal 0, m.length

    #MGS- now as bob try and make a request for another user's feed; will get error
    get :friends_plans, :id => users(:existingbob).id
    assert_success
    check_header("Skobee: Error displaying feed","Please check that the url to this feed is correct.","[^<]*/feeds")
    assert !@response.body.match("<item>")

    #MGS- now as bob try and make a request a feed without an ID
    get :friends_plans
    assert_success
    check_header("Skobee: Error displaying feed","Please check that the url to this feed is correct.","[^<]*/feeds")
    assert !@response.body.match("<item>")

    #MGS- add user_with_contacts as a friend and relogin to refresh your session
    bob.add_or_update_contact(user_with_contacts, { :friend_status => User::FRIEND_STATUS_FRIEND})
    login
    get :friends_plans, :id => bob.id
    assert_success

    #MGS- the general stuff should still be the same
    check_header("Skobee: bob's friends plans","A feed of bob's friends plans","[^<]*/users/contacts")
    #MGS- bob has a friend who has 4 plan chnages
    m = @response.body.scan(/<item>/)
    assert_equal 6, m.length
    #MGS- check the contents of one of the items
    change = plan_changes(:noaml_anniversary)
    check_feed_item("user_with_contacts suggested James's restaurant - second plan for place stats", change.updated_at.rfc2822.to_s, @controller.url_for(:controller => 'plans', :action => 'show', :id => change.plan.id, :cal_id => change.owner.planner.id, :only_path => false), "uri://skobee.com/PlanChange/#{change.id}")

    #MGS- add user_with_contacts as a contact and relogin to refresh your session
    bob.add_or_update_contact(users(:user_with_contacts), { :friend_status => User::FRIEND_STATUS_CONTACT})
    login
    get :friends_plans, :id => bob.id
    assert_success
    #MGS- now we should see no plans
    m = @response.body.scan(/<item>/)
    assert_equal 0, m.length

    #MGS- now add a plan to bob's planner to make sure it doesn't appear in this feed
    bob.planner.accept_plan(plans(:future_plan_2), bob)
    #MGS- login again to see this new plan
    login
    get :friends_plans, :id => bob.id
    assert_success
    #MGS- now we should see no plans
    m = @response.body.scan(/<item>/)
    assert_equal 0, m.length

    #MGS- add user_with_contacts as a friend and relogin to refresh your session
    bob.add_or_update_contact(users(:user_with_contacts), { :friend_status => User::FRIEND_STATUS_FRIEND})
    login
    get :friends_plans, :id => bob.id
    assert_success
    #MGS- since all planners are public, we should see the Who: field for all items
    assert_equal 6, @response.body.scan(/<item>/).length
    assert_equal 6, @response.body.scan(/Who:/).length

    #MGS- set planner to private
    planner = user_with_contacts.planner
    planner.visibility_type = SkobeeConstants::PRIVACY_LEVEL_PRIVATE
    planner.save

    login
    get :friends_plans, :id => bob.id
    assert_equal 0, @response.body.scan(/<item>/).length

    #MGS- set planner to FRIENDS only
    planner = user_with_contacts.planner
    planner.visibility_type = SkobeeConstants::PRIVACY_LEVEL_FRIENDS
    planner.save

    login
    #MGS- bob shouldn't be able to see any plans, as user_with_contacts hasn't added him as a friend
    get :friends_plans, :id => bob.id
    assert_equal 0, @response.body.scan(/<item>/).length

    #MGS- add user_with_contacts as a friend and relogin to refresh your session
    user_with_contacts.add_or_update_contact(bob, { :friend_status => User::FRIEND_STATUS_FRIEND})
    #MGS- bob shouldn't be able to all changes, as he is now a friend of user_with_contacts
    get :friends_plans, :id => bob.id
    assert_equal 6, @response.body.scan(/<item>/).length
  end

  def test_all_contacts_plans
    #MGS- pass valid credentials
    bob = users(:bob)
    auth = bob.login + ":atest"
    @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64(auth)}"
    get :all_contacts_plans, :id => bob.id
    assert_success
    assert_equal "application/xml; charset=utf-8", @response.headers['Content-Type']

    #MGS- bob has no friends, so he shouldn't see anything here
    # but the title of the feed should still be in here
    check_header("Skobee: All bob's contacts plans","A feed of all bob's contacts plans","[^<]*/users/contacts")

    #MGS- bob has no friends, thus he has no plans
    m = @response.body.scan(/<item>/)
    assert_equal 0, m.length

    #MGS- now as bob try and make a request for another user's feed; will get error
    get :all_contacts_plans, :id => users(:existingbob).id
    assert_success
    check_header("Skobee: Error displaying feed","Please check that the url to this feed is correct.","[^<]*/feeds")
    assert !@response.body.match("<item>")

    #MGS- now as bob try and make a request a feed without and ID
    get :all_contacts_plans
    assert_success
    check_header("Skobee: Error displaying feed","Please check that the url to this feed is correct.","[^<]*/feeds")
    assert !@response.body.match("<item>")

    #MGS- add user_with_contacts as a friend and relogin to refresh your session
    bob.add_or_update_contact(users(:user_with_contacts), { :friend_status => User::FRIEND_STATUS_FRIEND})
    login
    get :all_contacts_plans, :id => bob.id
    assert_success

    #MGS- the general stuff should still be the same
    check_header("Skobee: All bob's contacts plans", "A feed of all bob's contacts plans", "[^<]*/users/contacts")
    #MGS- bob has a friend who has 6 plan changes
    m = @response.body.scan(/<item>/)
    assert_equal 6, m.length
    #MGS- check the contents of one of the items
    change = plan_changes(:noaml_anniversary)
    check_feed_item("user_with_contacts suggested James's restaurant - second plan for place stats", change.updated_at.rfc2822.to_s, @controller.url_for(:controller => 'plans', :action => 'show', :id => change.plan.id, :cal_id => change.owner.planner.id, :only_path => false), "uri://skobee.com/PlanChange/#{change.id}")

    #MGS- add user_with_contacts as a friend and relogin to refresh your session
    bob.add_or_update_contact(users(:user_with_contacts), { :friend_status => User::FRIEND_STATUS_CONTACT})
    login
    get :all_contacts_plans, :id => bob.id
    assert_success
    #MGS- now we should still see 6 plan changes
    m = @response.body.scan(/<item>/)
    assert_equal 6, m.length

    #MGS- now add a plan to bob's planner to make sure it doesnt appear in this feed
    bob.planner.accept_plan(plans(:future_plan_2), bob)
    #MGS- login again to see this new plan
    login
    get :all_contacts_plans, :id => bob.id
    assert_success
    #MGS- now we should still see 6 plans not a 7th rsvp change for future_plan_2
    m = @response.body.scan(/<item>/)
    assert_equal 6, m.length
  end
  
  def test_plans
  	#MES- The plans feed is unsecured, and the ID is an ID of a planner OR the login of a user.
  	#	Only public planners can be shown.
  	get :plans, :id => planners(:first_planner).id
  	assert_success
  	res = @response.body
  	get :plans, :id => users(:bob).login
  	assert_success
  	assert_equal res, @response.body
  	assert_not_nil @response.body.match('<title>Skobee: bob\'s plans</title>')
  	
  	#MES- Non-public planners should NOT be available
  	plnr = planners(:user_with_friends_and_private_cal_planner)
  	assert_equal SkobeeConstants::PRIVACY_LEVEL_PRIVATE, plnr.visibility_type
  	get :plans, :id => plnr.id
  	assert_not_nil @response.body.match('<title>Skobee: Error displaying feed</title>')
  end
  
  def test_regulars
  	#MES- The regulars feed is unsecured, and the ID is an ID of a planner OR the login of a user.
  	#	Only public planners can be shown.
  	get :regulars, :id => planners(:first_planner).id
  	assert_success
  	res = @response.body
  	get :regulars, :id => users(:bob).login
  	assert_success
  	assert_equal res, @response.body
  	assert_not_nil @response.body.match('<title>Skobee: bob\'s regulars</title>')
  	
  	#MES- Non-public planners should NOT be available
  	plnr = planners(:user_with_friends_and_private_cal_planner)
  	assert_equal SkobeeConstants::PRIVACY_LEVEL_PRIVATE, plnr.visibility_type
  	get :regulars, :id => plnr.id
  	assert_not_nil @response.body.match('<title>Skobee: Error displaying feed</title>')
  end
end