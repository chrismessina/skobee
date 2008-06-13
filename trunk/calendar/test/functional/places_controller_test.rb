require File.dirname(__FILE__) + '/../test_helper'
require 'places_controller'

# Re-raise errors caught by the controller.
class PlacesController; def rescue_action(e) raise e end; end


#########################################################################################
#MES- Simple tests that just rely on users
#########################################################################################

class PlacesControllerTest_Simple < Test::Unit::TestCase

  fixtures :users, :emails

  def setup
    @controller = PlacesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_new
    login

    get :new

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:place)
    assert_valid_markup
  end

  def test_create
    login

    #KS- test correct creation
    num_places = Place.count

    post :create, :place => {:name => 'blah1', :location => '94103'}
    assert_response :redirect
    assert_redirected_to :action => 'show'

    num_places += 1
    assert_equal num_places, Place.count

    #KS- find the place, make sure the info is correct
    blah1 = Place.find_first(["name = ?", 'blah1'])
    assert_equal '94103', blah1.location
    assert_equal 1, blah1.user_id

    #KS- test bad phone #
    post :create, :place => {:name => 'blah2', :location => '94103', :phone => '123'}
    assert_equal num_places, Place.count

    #KS- test another bad phone #
    #MES- This is good now- we allow chars
    post :create, :place => {:name => 'blah3', :location => '94103', :phone => '510-asd-asdf'}
    num_places += 1
    assert_equal num_places, Place.count

    #KS- test yet another bad phone #
    #MES- This is good now- we allow chars
    post :create, :place => {:name => 'blah3', :location => '94103', :phone => 'fds-asd-asdf'}
    num_places += 1
    assert_equal num_places, Place.count

    #KS- test odd but good phone #
    post :create, :place => {:name => 'blah4', :location => '94103', :phone => '213()()4(5678--)90'}
    num_places += 1
    assert_equal num_places, Place.count
    place4 = Place.find(:first, :conditions => ['name = :name', { :name => 'blah4' }])
    assert_equal '2134567890', place4.phone

    #KS- test good phone # with leading 1
    post :create, :place => {:name => 'blah5', :location => '94103', :phone => '17162649362'}
    num_places += 1
    assert_equal num_places, Place.count
    place5 = Place.find(:first, :conditions => ['name = :name', { :name => 'blah5' }])
    assert_equal '7162649362', place5.phone

    #KS- test normal good phone #
    post :create, :place => {:name => 'blah6', :location => '94103', :phone => '(098)765-4320'}
    num_places += 1
    assert_equal num_places, Place.count
    place6 = Place.find(:first, :conditions => ['name = :name', { :name => 'blah6' }])
    assert_equal '0987654320', place6.phone

    #KS- test a normal good phone #
    post :create, :place => {:name => 'blah7', :location => '94103', :phone => '(213) 456-7890'}
    num_places += 1
    assert_equal num_places, Place.count
    place7 = Place.find(:first, :conditions => ['name = :name', { :name => 'blah7' }])
    assert_equal '2134567890', place7.phone

    #KS- test bad address -- should we make sure it's legit? -- currently we expect this to work
    post :create, :place => {:name => 'blah6', :location => 'n4ff'}
    num_places += 1
    assert_equal num_places, Place.count

    #KS- test same data OK
    post :create, :place => {:name => 'blah1', :location => '94103'}
    assert_response :redirect
    assert_redirected_to :action => 'show'
    num_places += 1
    assert_equal num_places, Place.count

    #KS- make sure place has proper public/private stuff set
    place = Place.find(:first, :conditions => "name = 'blah1'")
    assert_equal Place::PLACE_PRIVATE, place.public
    assert_equal Place::PUBLIC_STATUS_NOT_REQUESTED, place.public_status

    #KS- test setting the make this public checkbox
    post :create, :place => {:name => 'blah8', :location => 'um duh', :url => 'http://skobee.com', :public_status => '1' }
    num_places += 1
    assert_equal num_places, Place.count
    place8 = Place.find(:first, :conditions => "name = 'blah8'")
    assert_equal Place::PUBLIC_STATUS_REQUESTED, place8.public_status
  end

  def test_edit
    login

    #KS- initial place count (used later to verify create worked properly)
    num_places = Place.count

    #KS- create a place
    post :create, :place => {:name => 'basfdsdflah1', :location => '94103', :phone => '(415) 461-4242', :url => 'www.blah.com', :public_status => '1'}
    assert_response :redirect
    assert_redirected_to :action => 'show'
    num_places += 1
    assert_equal num_places, Place.count
    place = Place.find(:first, :conditions => ['name = :name', {:name => 'basfdsdflah1'}])

    #KS- should be able to view it since the current_user made it
    get :edit, :id => place.id
    assert_response :success

    #KS- edit every field then make sure expected values were set
    post :edit, :id => place.id, :place =>{:name => 'blah223423462sFDF', :location => '604 mission st, san francisco, ca 94105', :phone => '4153232323', :url => 'www.skobee.com'}
    assert_response :redirect
    assert_equal num_places, Place.count
    place = Place.find(place.id)
    assert_equal "blah223423462sFDF", place.name
    assert_equal "604 mission st, san francisco, ca 94105", place.location
    assert_equal "4153232323", place.phone
    assert_equal "www.skobee.com", place.url
    assert_equal place.public_status, Place::PUBLIC_STATUS_NOT_REQUESTED

    #KS- set everything to blank except name
    post :edit, :id => place.id, :place => {:name => 'DSVN9u8NVsdf', :location => '', :phone => '', :url => ''}
    assert_response :redirect
    place = Place.find(place.id)
    assert_equal num_places, Place.count
    assert_equal "DSVN9u8NVsdf", place.name
    assert_equal '', place.location
    assert_equal '', place.phone
    assert_equal '', place.url
    assert_equal place.public_status, Place::PUBLIC_STATUS_NOT_REQUESTED

    #KS- make it public, then try to edit it (shouldn't work)
    place.public = 1
    place.save
    assert_raise(RuntimeError){
      post :edit, :id => place.id, :place =>{:name => '9we78fhDSF', :location => '356 utah st, san francisco, ca 94103', :phone => '4082424242', :url => 'www.google.com'}
    }
    assert_raise(RuntimeError){
      get :edit, :id => place.id, :place =>{:name => '9we78fhDSF', :location => '356 utah st, san francisco, ca 94103', :phone => '4082424242', :url => 'www.google.com'}
    }
    place = Place.find(place.id)
    assert_equal num_places, Place.count
    assert_equal "DSVN9u8NVsdf", place.name
    assert_equal '', place.location
    assert_equal '', place.phone
    assert_equal '', place.url
    assert_equal place.public_status, Place::PUBLIC_STATUS_NOT_REQUESTED

    #KS- set it back to non public for the next test
    place.public = 0
    place.save

    #KS- try to edit it as another user (shouldn't work)
    login('existingbob', 'atest')
    assert_raise(RuntimeError) {
      post :edit, :id => place.id, :place =>{:name => '9we78fhDSF', :location => '356 utah st, san francisco, ca 94103', :phone => '4082424242', :url => 'www.google.com'}
    }
    place = Place.find(place.id)
    assert_equal num_places, Place.count
    assert_equal "DSVN9u8NVsdf", place.name
    assert_equal '', place.location
    assert_equal '', place.phone
    assert_equal '', place.url
    assert_equal place.public_status, Place::PUBLIC_STATUS_NOT_REQUESTED

    #KS- try to even look at it
    assert_raise(RuntimeError) {
      get :edit, :id => place.id
    }
  end

  def test_report_error
    login
    get :report_error
    assert_valid_markup
  end
end


#########################################################################################
#MES- Tests that require places fixture
#########################################################################################

class PlacesControllerTest_Places < Test::Unit::TestCase

  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :places, :users, :emails

  def setup
    @controller = PlacesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_check_read_access_helper
    #KS- private place someone else is the owner of should throw an exception
    assert_equal users(:user_with_friends_and_friends_cal), places(:place_owned_by_user_with_friends_and_friends_cal).owner
    assert_equal Place::PLACE_PRIVATE, places(:place_owned_by_user_with_friends_and_friends_cal).public
    assert_raise(RuntimeError){ @controller.check_read_access_helper(places(:place_owned_by_user_with_friends_and_friends_cal), nil, users(:bob)) }

    #KS- private place no one is the owner of should throw an exception
    assert_nil places(:private_venue_with_no_owner).owner
    assert_equal Place::PLACE_PRIVATE, places(:private_venue_with_no_owner).public
    assert_raise(RuntimeError){ @controller.check_read_access_helper(places(:private_venue_with_no_owner), nil, users(:bob)) }

    #KS- private place bob is the owner of should be fine
    assert_equal users(:bob), places(:private_vlue).owner
    assert_equal Place::PLACE_PRIVATE, places(:private_vlue).public
    assert_equal places(:private_vlue), @controller.check_read_access_helper(places(:private_vlue), nil, users(:bob))

    #KS- public place owned by someone else should be fine
    assert_equal users(:x_dummy_user_4), places(:superfluous_place).owner
    assert_equal Place::PLACE_PUBLIC, places(:superfluous_place).public
    assert_equal places(:superfluous_place), @controller.check_read_access_helper(places(:superfluous_place), nil, users(:bob))

    #KS- public place owned by no one should be fine
    assert_nil places(:another_place).owner
    assert_equal Place::PLACE_PUBLIC, places(:another_place).public
    assert_equal places(:another_place), @controller.check_read_access_helper(places(:another_place), nil, users(:bob))

    #KS- public place owned by bob should be fine
    assert_equal users(:bob), places(:place_owned_by_bob).owner
    assert_equal Place::PLACE_PUBLIC, places(:place_owned_by_bob).public
    assert_equal places(:place_owned_by_bob), @controller.check_read_access_helper(places(:place_owned_by_bob), nil, users(:bob))
  end

  def test_record_error
    #MES- Posting to record_error should record a feedback object
    login
    ct = Feedback.count
    post :record_error, :report_url => 'http://test.url.com', :id => places(:first_place).id, :body => 'test body'
    assert_equal ct + 1, Feedback.count
  end

  def test_search_niceties
    login
    #MES- Test some of the more advances stuff for search

    #MES- Search with NO criteria, should get a flash warning
    get :search
    assert_tag :tag => 'div', :attributes => { :id => "flash-error" }, :content => /You must enter a 'what'/


    #MES- Search with a bogus address, should get a flash explaining the search failed
    get :search, :location => 'undecipherable', :max_distance => '10'
    assert_tag :tag => 'div', :attributes => { :id => "flash-error" }, :content => /undecipherable/
  end

end

#########################################################################################
#MES- Tests that depend on plans
#########################################################################################

class PlacesControllerTest_Plans < Test::Unit::TestCase

  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :places, :users, :emails, :plans, :planners, :planners_plans, :user_contacts

  def setup
    @controller = PlacesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_show
    login

    get :show, :id => places(:first_place).id

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:place)
    assert assigns(:place).valid?

    #MES- Plan future_plan_1 should be a recent plan, so it should be displayed
    assert_tag :tag => 'dt', :content => plans(:future_plan_1).name

    #MES- The 'Add Comment' link should be displayed
    assert_tag :tag => 'a', :content => 'Add Comment'

    assert_valid_markup
  end

  def test_show_not_authenticated
    logout

    get :show, :id => places(:first_place).id

    assert_response :success
    assert_template 'show'

    #MES- Plan future_plan_1 should be a recent plan, so it should be displayed
    assert_tag :tag => 'dt', :content => plans(:future_plan_1).name

    #MES- The 'Add Comment' link should NOT be displayed since we're not authenticated
    assert_no_tag :tag => 'a', :content => 'Add Comment'

    assert_valid_markup

    #MES- If the planner is 'friends only', then the plan should NOT show up
    plnr = planners(:friend_1_of_user_planner)
    plnr.visibility_type = SkobeeConstants::PRIVACY_LEVEL_FRIENDS
    plnr.save!
    plnr = planners(:user_with_friends_planner)
    plnr.visibility_type = SkobeeConstants::PRIVACY_LEVEL_FRIENDS
    plnr.save!
    get :show, :id => places(:first_place).id
    assert_response :success

    assert_no_tag :tag => 'dt', :content => plans(:future_plan_1).name
  end

  def test_security
    login

    #MES- When viewing places, you should be able to see places that are public, or
    # that you own, or that are associated with a plan that you are also
    # associated with.  You should NOT be able to see other places.

    #MES- Bob can see all the places
    login
    get :show, :id => places(:first_place).id
    assert_response :success, 'Bob couldn\'t see the first place'
    get :show, :id => places(:another_place).id
    assert_response :success, 'Bob couldn\'t see another place'
    get :show, :id => places(:place_owned_by_bob).id
    assert_response :success, 'Bob couldn\'t see his place'

    #MES- Existingbob can see the public places, but not Bob's place
    login users(:existingbob)
    get :show, :id => places(:first_place).id
    assert_response :success, 'Existingbob couldn\'t see the first place'
    get :show, :id => places(:another_place).id
    assert_response :success, 'Existingbob couldn\'t see another place'
    assert_raise(RuntimeError) { get :show, :id => places(:place_owned_by_user_with_friends_and_friends_cal).id }
    #MES- Passing in a bogus plan shouldn't work
    assert_raise(ActiveRecord::RecordNotFound) { get :show, :id => places(:place_owned_by_user_with_friends_and_friends_cal).id, :plan_id => -1 }
    #MES- Passing in a plan that isn't related to the place shouldn't work
    assert_raise(RuntimeError) { get :show, :id => places(:place_owned_by_user_with_friends_and_friends_cal).id, :plan_id => plans(:another_plan).id }
    #MES- Passing in a plan that the user isn't on shouldn't work
    assert_raise(RuntimeError) { get :show, :id => places(:place_owned_by_user_with_friends_and_friends_cal).id, :plan_id => plans(:another_plan_for_bob_place).id }
    #MES- When the user is attending a plan at the place, they should be able to see the place
    get :show, :id => places(:place_owned_by_user_with_friends_and_friends_cal).id, :plan_id => plans(:plan_for_bob_place).id
    assert_response :success, 'Existingbob couldn\'t see the place associated with a plan he is attending'

    #MGS- if you can see someones planner, then you can see private venues associated with a plan on that venue
    login users(:existingbob)
    #MGS- exisitingbob isn't on this plan; should raise Current user is not associated with plan
    assert_raise(RuntimeError) {get :show, :id => places(:place_owned_by_user_with_friends_and_friends_cal).id, :plan_id => plans(:plan_just_for_user_with_friends_and_friends_cal).id}
    #MGS- exisitingbob doesn't have the visibility level required for this planner; should raise Planner not visible to current user
    assert_raise(RuntimeError) {get :show, :id => places(:place_owned_by_user_with_friends_and_friends_cal).id, :plan_id => plans(:plan_just_for_user_with_friends_and_friends_cal).id, :cal_id => planners(:user_with_friends_and_friends_cal_planner).id}
    #MGS- request with a bogus planner id; should raise Planner does not include plan
    assert_raise(RuntimeError) {get :show, :id => places(:place_owned_by_user_with_friends_and_friends_cal).id, :plan_id => plans(:plan_just_for_user_with_friends_and_friends_cal).id, :cal_id => planners(:existingbob_planner).id}

    #MGS- now log in as someone who can see this planner
    login users(:friend_1_of_user)
    #MGS- still should raise an error; if no cal id is passed on the querystring; should raise Current user is not associated with plan
    assert_raise(RuntimeError) {get :show, :id => places(:place_owned_by_user_with_friends_and_friends_cal).id, :plan_id => plans(:plan_just_for_user_with_friends_and_friends_cal).id}
    #MGS- pass the wrong planner id for another failure; should raise planner doesnt include plan
    assert_raise(RuntimeError) {get :show, :id => places(:place_owned_by_user_with_friends_and_friends_cal).id, :plan_id => plans(:plan_just_for_user_with_friends_and_friends_cal).id, :cal_id => planners(:friend_1_of_user_planner).id}
    #MGS- pass in the planner id but not the plan id; should raise Current user doesn't have read rights on place and plan_id is nil
    assert_raise(RuntimeError) {get :show, :id => places(:place_owned_by_user_with_friends_and_friends_cal).id, :cal_id => planners(:user_with_friends_and_friends_cal_planner).id}
    #MGS- now pass in the right planner id with the right user
    #MES- When the user is attending a plan at the place, they should be able to see the place
    get :show, :id => places(:place_owned_by_user_with_friends_and_friends_cal).id, :plan_id => plans(:plan_just_for_user_with_friends_and_friends_cal).id, :cal_id => planners(:user_with_friends_and_friends_cal_planner).id
    assert_response :success, 'friend_1_of_user couldn\'t see a private place through user_with_friends_and_friends_cal\'s planner'
  end

  def test_search
    login

    #MGS-validate XHTML
    get :find_places
    assert_valid_markup

    #MES- We need the place statistics data to be in there, for place search by time to work
    Place.update_usage_stats

    mock_opens = {
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=4209+Howe+St%2C+Oakland%2C+CA%2C+94611' => './test/mocks/resources/4209_howe_complete.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=undecipherable' => './test/mocks/resources/undecipherable_yahoo.xml'
    }
    with_mock_opens(mock_opens) do
      #MES- Search by full text
      get :search, :fulltext => "Chinese"
      assert_tag :tag => 'h3', :content => "China Bistro Chinese Restaurant"
      assert_tag :tag => 'h3', :content => "Bamboo House Chinese Rstrnt"

      #MES- Full text should not pay attention to punctuation
      get :search, :fulltext => "Ha'n Ze!n"
      assert_tag :tag => 'h3', :content => 'Hana Zen'


      #MES- Search by location and text
      get :search, :fulltext => "hana", :location => '4209 Howe St, Oakland, CA, 94611', :max_distance => '10'
      assert_tag :tag => 'h3', :content => 'Hana Zen'


      #MES- Search places by time
      tz = TZInfo::Timezone.get('America/Tijuana')
      target_time = tz.utc_to_local(Time.utc(Time.now.year + 1, 6, 6, 13, 0, 0, 0))
      target_day = target_time.wday
      get :search, :fulltext => 'search', :days => target_day.to_s, :timeperiod => Plan::TIME_DESCRIPTION_BREAKFAST.to_s
      assert_tag :tag => 'h3', :content => '2F21F2C994EE48908B4704550961E7A7'
      assert_tag :tag => 'h3', :content => 'D4E484F04EBF4B41ABF39FC3416D97F3, search for abcde'


      #MES- Search by text and location
      get :search, :fulltext => "Hana", :location => '4209 Howe St, Oakland, CA, 94611', :max_distance => '10'
      assert_tag :tag => 'h3', :content => 'Hana Zen'


      #MES- Search by text and time
      get :search, :fulltext => "2F21F2C994EE48908B4704550961E7A7", :days => target_day.to_s, :timeperiod => Plan::TIME_DESCRIPTION_BREAKFAST.to_s
      assert_tag :tag => 'h3', :content => '2F21F2C994EE48908B4704550961E7A7'
      assert_no_tag :tag => 'h3', :content => 'D4E484F04EBF4B41ABF39FC3416D97F3, search for abcde'


      #MES- Search by location and time
      get :search, :fulltext => 'search', :location => '4209 Howe St, Oakland, CA, 94611', :max_distance => '10', :days => target_day.to_s, :timeperiod => Plan::TIME_DESCRIPTION_BREAKFAST.to_s
      assert_tag :tag => 'h3', :content => '2F21F2C994EE48908B4704550961E7A7'
      assert_no_tag :tag => 'h3', :content => 'D4E484F04EBF4B41ABF39FC3416D97F3, search for abcde'


      #MES- Search 'em all
      get :search, :fulltext => "2F21F2C994EE48908B4704550961E7A7", :location => '4209 Howe St, Oakland, CA, 94611', :max_distance => '10', :days => target_day.to_s, :timeperiod => Plan::TIME_DESCRIPTION_BREAKFAST.to_s
      assert_tag :tag => 'h3', :content => '2F21F2C994EE48908B4704550961E7A7'
      assert_no_tag :tag => 'h3', :content => 'D4E484F04EBF4B41ABF39FC3416D97F3, search for abcde'
      #MGS- validate XHTML on results page
      assert_valid_markup
    end
  end

end

#########################################################################################
#MES- Tests related to comments
#########################################################################################

class PlacesControllerTest_Comments < Test::Unit::TestCase

  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :places, :users, :emails, :comments, :comments_places, :planners

  def setup
    @controller = PlacesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_comments
    login users(:user_with_friends)

    #add comment
    post :add_comment_ajax, :place_id => places(:superfluous_place).id, :comment_tb => "this is a new comment"

    assert_success
    assert_tag :tag=>"p", :content => "this is a new comment"

    place = assigns(:place)
    comments = place.comments
    #MGS- we can do this because this should be the only comment
    assert_equal 1, comments.length
    comment_id = comments[0].id

    #edit comment
    post :edit_comment_ajax, :comment_id=> comment_id, :place_id => places(:superfluous_place).id, "comment_edit_tb#{comment_id}" => "this is the edited comment"

    assert_success
    assert_tag :tag=>"p", :content => "this is the edited comment"

    #delete comment
    post :delete_comment_ajax, :comment_id=> comment_id, :place_id => places(:superfluous_place).id

    place = places(:superfluous_place)
    comments = place.comments
    #MGS- the comment should have been deleted
    assert comments.length == 0


    get :show, :id=> places(:superfluous_place).id
    assert_success
    assert_valid_markup


    #MGS- test truncating a long comment
    #add comment
    post :add_comment_ajax, :place_id => places(:superfluous_place).id, :comment_tb => "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Duis aliquam nisl ullamcorper est. Quisque in dui viverra enim mattis lobortis. Praesent sit amet augue id enim volutpat posuere. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Donec condimentum lacus eget arcu. Suspendisse et velit. Vestibulum a ante a neque tristique vehicula. Sed laoreet, ligula nec imperdiet mattis, pede felis dapibus mauris, sit amet vestibulum lorem elit dapibus tellus. Vivamus vel massa. Ut sagittis, ligula vel laoreet placerat, mi velit dapibus est, vitae dapibus purus nibh vitae nunc. Praesent sit amet lectus. Mauris suscipit mi vel mi faucibus pellentesque. Phasellus sodales rutrum magna. Duis imperdiet dolor sit amet nisl. Etiam magna. Pellentesque molestie venenatis ante. Nullam tellus elit, volutpat eget, elementum eu, rutrum tempus, arcu. Nulla arcu augue, sodales vel, gravida id, viverra nec, magna.Maecenas adipiscing diam vel metus. Aenean risus ipsum, pulvinar in, bibendum vel, auctor ac, tellus. Fusce non ligula nec massa consequat egestas. Etiam bibendum. In hac habitasse platea dictumst. Donec id odio. Curabitur pretium dolor eu leo. Vivamus ornare. Curabitur velit pede, gravida porttitor, malesuada mattis, molestie sit amet, risus. In a orci eu lectus dapibus aliquam. Curabitur faucibus nunc. Donec diam. Sed pede. Praesent a nulla. Praesent pretium. Aenean vestibulum.Integer sagittis neque a mi. Ut commodo blandit odio. Nam augue augue, egestas sit amet, consectetuer in, faucibus at, pede. Praesent a pede eget sem sollicitudin lobortis. Maecenas semper. Praesent tincidunt vestibulum justo. Cras sit amet odio ac urna blandit consequat. Etiam id lorem nec quam lacinia vehicula. Suspendisse consequat faucibus mauris. Aliquam dapibus. Praesent commodo. Proin ultrices, ligula sed iaculis pretium, erat turpis pellentesque velit, eget pretium lorem arcu sit amet felis. Suspendisse potenti.Quisque faucibus pede at enim tincidunt bibendum. Curabitur eu nibh. Aliquam lobortis arcu eu libero. Donec nibh metus, mollis eget, ultrices at, lacinia ut, urna. Sed sollicitudin blandit tellus. Praesent lectus. Cras quis diam. Aliquam massa turpis, adipiscing ac, porttitor a, suscipit et, elit. In hac habitasse platea dictumst. Suspendisse erat odio, dignissim non, rutrum id, sodales vel, elit. Mauris in tortor. Cras in orci ac lectus vestibulum varius. Quisque dignissim sem in massa. Suspendisse turpis sapien, auctor a, cursus a, blandit eu, leo. Mauris vel est. Mauris ultricies dolor varius sem. Sed euismod est vitae velit. Suspendisse luctus auctor mauris.Ut volutpat, arcu nec blandit tristique, sapien justo venenatis odio, vel suscipit ipsum mauris sit amet lacus. Vestibulum felis lacus, vestibulum et, vulputate a, semper eget, magna. Sed convallis luctus diam. Sed feugiat ante blandit neque. Donec sed metus in arcu consequat convallis. Nam volutpat. Ut ante ipsum, fermentum eu, faucibus aliquet, accumsan at, velit. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Nulla facilisi. Nullam elit sapien, rhoncus in, vulputate eget, pharetra ac, elit. Praesent eget orci. Etiam lacus. Ut feugiat enim ac orci. Aenean vitae leo sed lorem imperdiet tempus. Mauris est arcu, hendrerit sit amet, viverra non, volutpat sit amet, erat. Cras porta, orci ac hendrerit convallis, est lorem volutpat velit, eget aliquam quam orci tincidunt dolor.Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Vestibulum ligula purus, ullamcorper at, ultricies placerat, ultricies vitae, lorem. Proin euismod. Maecenas semper enim ultrices neque. Quisque consequat augue eu eros. Pellentesque libero. Cras accumsan. Fusce ut magna. Suspendisse porttitor fringilla metus. Duis felis. Cras pretium orci nec nulla. Etiam fringilla dictum magna. In adipiscing porta tellus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Ut ligula eros, imperdiet feugiat, porttitor ut, convallis ac, ligula. Sed leo arcu, iaculis non, auctor id, luctus eu, sem. Cras et ligula et massa luctus luctus. In hac habitasse platea dictumst. Donec nonummy.Donec quis tortor. Aenean lobortis leo et nisl. Ut volutpat rutrum sapien. In dolor orci, viverra eu, sagittis in, rhoncus eget, mauris. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Fusce eget enim quis risus ornare molestie. Nulla ut est. Maecenas massa urna, porta sit amet, euismod sit amet, lacinia in, tortor. Nunc convallis condimentum nisl. Donec est. Nunc condimentum ipsum gravida nunc. Nulla interdum semper lacus. Vivamus odio turpis, malesuada in, imperdiet nec, aliquam elementum, erat. Phasellus adipiscing condimentum ligula. Quisque rutrum massa non neque. Donec laoreet diam ut leo. Suspendisse dui erat, egestas a, feugiat quis, pharetra vitae, ipsum. Nulla convallis dolor a purus. Sed felis magna, auctor id, pretium et, lobortis rutrum, nibh. Suspendisse massa nunc."
    assert_success
    assert_tag :tag=>"p", :content => "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Duis aliquam nisl ullamcorper est. Quisque in dui viverra enim mattis lobortis. Praesent sit amet augue id enim volutpat posuere. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Donec condimentum lacus eget arcu. Suspendisse et velit. Vestibulum a ante a neque tristique vehicula. Sed laoreet, ligula nec imperdiet mattis, pede felis dapibus mauris, sit amet vestibulum lorem elit dapibus tellus. Vivamus vel massa. Ut sagittis, ligula vel laoreet placerat, mi velit dapibus est, vitae dapibus purus nibh vitae nunc. Praesent sit amet lectus. Mauris suscipit mi vel mi faucibus pellentesque. Phasellus sodales rutrum magna. Duis imperdiet dolor sit amet nisl. Etiam magna. Pellentesque molestie venenatis ante. Nullam tellus elit, volutpat eget, elementum eu, rutrum tempus, arcu. Nulla arcu augue, sodales vel, gravida id, viverra nec, magna.Maecenas adipiscing diam vel metus. Aenean risus ipsum, pulvinar in, bibendum vel, auctor ac, tellus. Fusce non ligula nec massa consequat egestas. Etiam bibendum. In hac habitasse platea dictumst. Donec id odio. Curabitur pretium dolor eu leo. Vivamus ornare. Curabitur velit pede, gravida porttitor, malesuada mattis, molestie sit amet, risus. In a orci eu lectus dapibus aliquam. Curabitur faucibus nunc. Donec diam. Sed pede. Praesent a nulla. Praesent pretium. Aenean vestibulum.Integer sagittis neque a mi. Ut commodo blandit odio. Nam augue augue, egestas sit amet, consectetuer in, faucibus at, pede. Praesent a pede eget sem sollicitudin lobortis. Maecenas semper. Praesent tincidunt vestibulum justo. Cras sit amet odio ac urna blandit consequat. Etiam id lorem nec quam lacinia vehicula. Suspendisse consequat faucibus mauris. Aliquam dapibus. Praesent commodo. Proin ultrices, ligula sed iaculis pretium, erat turpis pellentesque velit, eget pretium lorem arcu sit amet felis. Suspendisse potenti.Quisque faucibus pede at enim tincidunt bibendum. Curabitur eu nibh. Aliquam lobortis arcu eu libero. Donec nibh metus, mollis eget, ultrices at, lacinia ut, urna. Sed sollicitudin blandit tellus. Praesent lectus. Cras quis diam. Aliquam massa turpis, adipiscing ac, porttitor a, suscipit et, elit. In hac habitasse platea dictumst. Suspendisse erat odio, dignissim non, rutrum id, sodales vel, elit. Mauris in tortor. Cras in orci ac lectus vestibulum varius. Quisque dignissim sem in massa. Suspendisse turpis sapien, auctor a, cursus a, blandit eu, leo. Mauris vel est. Mauris ultricies dolor varius sem. Sed euismod est vitae velit. Suspendisse luctus auctor mauris.Ut volutpat, arcu nec blandit tristique, sapien justo venenatis odio, vel suscipit ipsum mauris sit amet lacus. Vestibulum felis lacus, vestibulum et, vulputate a, semper eget, magna. Sed convallis luctus diam. Sed feugiat ante blandit neque. Donec sed metus in arcu consequat convallis. Nam volutpat. Ut ante ipsum, fermentum eu, faucibus aliquet, accumsan at, velit. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Nulla facilisi. Nullam elit sapien, rhoncus in, vulputate eget, pharetra ac, elit. Praesent eget orci. Etiam lacus. Ut feugiat enim ac orci. Aenean vitae leo sed lorem imperdiet tempus. Mauris est arcu, hendrerit sit amet, viverra non, volutpat sit amet, erat. Cras porta, orci ac hendrerit convallis, est lorem volutpat velit, eget aliquam quam orci tincidunt dolor.Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Vestibulum ligula purus, ullamcorper at, ultricies placerat, ultricies vitae, lorem. Proin euismod. Maecenas semper enim ultrices neque. Quisque consequat augue eu eros. Pellentesque libero. Cras accumsan. Fusce ut magna. Suspendisse porttitor fringilla metus. Duis felis. Cras pretium orci nec nulla. Etiam fringilla dictum magna. In adipiscing porta tellus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos hymenaeos. Ut ligula eros, imperdiet feugiat, porttitor ut, convallis ac, ligula. Sed leo arcu, iaculis non, auctor id, luctus eu, sem. Cras et ligula et"

    get :show, :id=> places(:superfluous_place).id
    assert_success
    assert_valid_markup
  end

end
