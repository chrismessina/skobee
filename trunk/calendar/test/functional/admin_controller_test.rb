require File.dirname(__FILE__) + '/../test_helper'
require 'admin_controller'
require 'places_controller'

# Raise errors beyond the default web-based presentation
class AdminController; def rescue_action(e) raise e end; end
class PlacesController; def rescue_action(e) raise e end; end

#########################################################################################
#MES- Simple tests that only rely on the users and emails tables
#########################################################################################

class AdminControllerTest_Simple < Test::Unit::TestCase
  fixtures :users, :emails

  def setup
    @controller = AdminController.new
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
    @request.host = "localhost"
  end


  def test_no_access_for_non_admin
    #MES- Non-admins should not be able to see anything in this controller
    login

    get :stats
    assert_redirect

    get :impersonate
    assert_redirect

    get :approve_places
    assert_redirect
  end

  def test_impersonate
    #MES- Admin users should be able to impersonate
    usr = users(:treat_as_administrator)
    usr.user_type = User::USER_TYPE_ADMIN
    usr.save
    login usr

    get :impersonate, :user => users(:bob).id

    assert_equal users(:bob).id, @response.session['user_id']
  end

end

#########################################################################################
#MES- Tests that depend on places and planners
#########################################################################################

class AdminControllerTest_Places < Test::Unit::TestCase
  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :users, :emails, :planners, :places

  def setup
    @controller = AdminController.new
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
    @request.host = "localhost"
  end

  def test_stats
    #MES- Admin users should be able to see stats
    usr = users(:treat_as_administrator)
    usr.user_type = User::USER_TYPE_ADMIN
    usr.save
    login usr

    get :stats
    assert_success
  end

  def test_approve_places_1
    #MGS- test the approve places page

    mock_opens = {
      'http://api.local.yahoo.com/LocalSearchService/V2/localSearch?appid=just_to_test&query=requested+public+place&location=500+Sansome+San+Francisco%2C+CA&radius=50&results=20' => './test/mocks/resources/request_public_place_500_sansome.xml'
    }
    with_mock_opens(mock_opens) do
      #MGS- bob shouldn't be able to see this page as this is a private place, awaiting approval
      login users(:bob)
      assert_raise(RuntimeError) {get_to_controller(PlacesController.new, :show, { :id => places(:requested_public_place).id })}

      usr = users(:treat_as_administrator)
      usr.user_type = User::USER_TYPE_ADMIN
      usr.save
      login usr
      get :approve_places
      assert_success
      assert_tag :tag => 'td', :content => /requested public place/

      get :edit_place, :id => places(:requested_public_place).id
      assert_success
      assert_tag :tag => 'input', :attributes => {:value => "requested public place"}

      place = Place.find(places(:requested_public_place).id)
      assert_equal Place::PLACE_PRIVATE, place.public
      assert_equal Place::PUBLIC_STATUS_REQUESTED, place.public_status
      assert_equal 0, place.geocoded
      #MGS- look for items returned in the search results
      assert_tag :tag => "td", :content => "Edwardian San Francisco Hotel"
      assert_tag :tag => "td", :content => "1668 Market St"

      post :update_place, :id => places(:requested_public_place).id,
                          :places =>
                          {:name => "skobee inc",
                          :city =>"San Francisco",
                          :zip => "94105",
                          :public => "1",
                          :url => "http://www.skobee.com",
                          :phone => "415-999-9999",
                          :address => "604 Mission St",
                          :location => "604 Mission St San Francisco, CA 94105",
                          :state => "CA"},
                          :commit => "Edit"
      assert_redirected_to "places/show/#{places(:requested_public_place).id}"
      place = Place.find(places(:requested_public_place).id)
      assert_equal Place::PLACE_PUBLIC, place.public
      assert_equal Place::PUBLIC_STATUS_NOT_REQUESTED, place.public_status
      assert_equal 'skobee inc', place.name
      assert_equal 'San Francisco', place.city
      assert_equal '604 Mission St San Francisco, CA 94105', place.location
      assert place.zip.match(/94105/)
      assert_equal 'http://www.skobee.com', place.url
      assert place.phone.match(/4159999999/)
      assert_equal '604 Mission St', place.address
      assert_equal 'CA', place.state
      assert_equal 1, place.geocoded
    end

    #MGS- bob should be able to see this place now, as it's public
    login users(:bob)
    get_to_controller(PlacesController.new, :show, { :id => places(:requested_public_place).id })
    assert_not_equal "500 Internal Error", @response.headers["Status"]
  end

  def test_approve_places_2
    #MES- If we do a GET, we should see the page
    usr = users(:treat_as_administrator)
    usr.user_type = User::USER_TYPE_ADMIN
    usr.save
    login usr

    get :approve_places
    assert_success

    #MES- We should be able to post to do_approve_places to approve places
    plc = places(:requested_public_place)
    assert_equal Place::PUBLIC_STATUS_REQUESTED, plc.public_status
    assert_equal Place::PLACE_PRIVATE, plc.public
    post :do_approve_places, "place_#{plc.id}" => 1
    plc = places(:requested_public_place, :force)
    assert_equal Place::PUBLIC_STATUS_NOT_REQUESTED, plc.public_status
    assert_equal Place::PLACE_PUBLIC, plc.public

    #MES- Same deal, but for do_reject_places
    plc.public_status = Place::PUBLIC_STATUS_REQUESTED
    plc.public = Place::PLACE_PRIVATE
    plc.save
    post :do_reject_places, "place_#{plc.id}" => 1
    plc = places(:requested_public_place, :force)
    assert_equal Place::PUBLIC_STATUS_NOT_REQUESTED, plc.public_status
    assert_equal Place::PLACE_PRIVATE, plc.public

  end
end
