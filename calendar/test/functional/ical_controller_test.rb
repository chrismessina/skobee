require File.dirname(__FILE__) + '/../test_helper'
require 'ical_controller'

# Re-raise errors caught by the controller.
class IcalController; def rescue_action(e) raise e end; end

class IcalControllerTest_1 < Test::Unit::TestCase
  fixtures :users, :emails, :planners
  include ApplicationHelper

  def setup
    @controller = IcalController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_security
    #MGS- make sure you have to login to see this page
    bob = users(:bob)
    existing_bob = users(:existingbob)

    assert_raise(RuntimeError) { get :publish }
    assert_raise(RuntimeError) { get :publish, :id => bob.planner.id }
    assert_raise(RuntimeError) { get :publish, :user_id => bob.id }
    assert_raise(RuntimeError) { get :publish, :id => bob.planner.id, :user_id => bob.id }

    correct_hash = generate_ical_key(bob, bob.planner.id)
    #MGS- make a request with the correct ikey
    get :publish, :id => bob.planner.id, :user_id => bob.id, :ikey => correct_hash
    assert_success

    #MGS- try a couple of bob/existing_bob combos, to make sure you get errors
    assert_raise(RuntimeError) { get :publish, :id => existing_bob.planner.id, :user_id => existing_bob.id, :ikey => correct_hash }
    assert_raise(RuntimeError) { get :publish, :id => bob.planner.id, :user_id => existing_bob.id, :ikey => correct_hash }
  end

  def test_ical_fields
    bob = users(:bob)
    existingbob = users(:existingbob)
    correct_hash = generate_ical_key(bob, bob.planner.id)
    #MGS- make a request with the correct ikey
    get :publish, :id => bob.planner.id, :user_id => bob.id, :ikey => correct_hash
    assert_success

    #MGS- check the content type
    assert_equal "text/calendar", @response.headers['Content-Type']

    #MGS- bob has no solid plans
    m = @response.body.scan(/BEGIN:VEVENT/).length
    assert_equal 0, m
    #MGS- bob has no fuzzy plans
    m = @response.body.scan(/BEGIN:VTASK/).length
    assert_equal 0, m

    #MGS- check the header if the publish feed, even though theres nothing in it
    assert_equal 1, @response.body.scan(/BEGIN:VCALENDAR/).length
    assert_equal 1, @response.body.scan(/VERSION:2.0/).length
    assert_equal 1, @response.body.scan(/PRODID/).length
    assert_equal 1, @response.body.scan(/CALSCALE:Gregorian/).length
    assert_equal 1, @response.body.scan(/METHOD:PUBLISH/).length
    assert @response.body.match(Regexp.escape("X-WR-CALNAME:#{Inflector.possessiveize(bob.login)} Skobee Plans"))
    assert_equal 1, @response.body.scan(/END:VCALENDAR/).length

    #MGS- make a fuzzy plan for bob
    login
    get_to_controller(PlansController.new, :create, { :plan => {:name => "test plan"}, :dateperiod => 7, :timeperiod => 3 })
    fuzzy_plan = assigns(:plan)
    logout

    #@controller = IcalController.new
    get :publish, :id => bob.planner.id, :user_id => bob.id, :ikey => correct_hash
    assert_success

    #MGS- bob has no solid plans
    m = @response.body.scan(/BEGIN:VEVENT/).length
    assert_equal 0, m
    #MGS- bob has one fuzzy plans
    m = @response.body.scan(/BEGIN:VTODO/).length
    assert_equal 1, m

    m = @response.body.match(/BEGIN:VTODO.*END:VTODO/m)
    todo = m[0]
    assert !todo.blank?

    assert todo.match(/TRANSP:OPAQUE/m)
    assert todo.match(/DTSTAMP/m)
    assert todo.match(/LAST-MODIFIED/m)
    assert todo.match(/CREATED/m)

    url = Regexp.escape(@controller.url_for(:controller => 'plans', :action => 'show', :id => fuzzy_plan.id, :cal_id => bob.planner.id ))
    re_url = Regexp.new("URL:#{url}")
    assert todo.match(url)

    assert todo.match(/STATUS:TENTATIVE/m)
    assert !todo.match(/DESCRIPTION/)
    assert todo.match(/DTSTART/)
    assert todo.match(/DTEND/)
    re_summary = Regexp.new("SUMMARY:#{fuzzy_plan.name}")
    assert todo.match(re_summary)

    #MGS- now make a solid plan
    login
    get_to_controller(PlansController.new, :create, { :plan => {:name => "another test test plan", :description => "another test plan description" }, :dateperiod => 0, :timeperiod => 3,
                      :date_month => 5, :date_day => 24, :date_year => 2010, :plan_who => "existingbob", :place_origin => "2",
                      :place_name => "Bob's Donuts", :place_location => "1621 Polk St. San Francisco, CA 94109"
                      })
    solid_plan = assigns(:plan)
    logout

    #@controller = IcalController.new
    get :publish, :id => bob.planner.id, :user_id => bob.id, :ikey => correct_hash
    assert_success

    #MGS- bob has one solid plans
    m = @response.body.scan(/BEGIN:VEVENT/).length
    assert_equal 1, m
    #MGS- bob has one fuzzy plans
    m = @response.body.scan(/BEGIN:VTODO/).length
    assert_equal 1, m

    m = @response.body.match(/BEGIN:VEVENT.*END:VEVENT/m)
    #MGS- remove line breaks
    event = m[0]
    assert !event.blank?

    assert event.match(/TRANSP:OPAQUE/m)
    assert event.match(/DTSTAMP/m)
    assert event.match(/LAST-MODIFIED/m)
    assert event.match(/CREATED/m)
    assert event.match(/STATUS:CONFIRMED/m)
    re_desc = Regexp.new("SUMMARY:#{solid_plan.description}")
    assert event.match(/DESCRIPTION/)
    assert event.match(/DTSTART/)
    assert event.match(/DTEND/)
    re_summary = Regexp.new("SUMMARY:#{solid_plan.name}")
    assert event.match(re_summary)

    #MGS- check the attendee lists
    re_attendees = Regexp.new("ATTENDEE;PARTSTAT=NEEDS-ACTION;ROLE=REQ-PARTICIPANT;CN=#{existingbob.real_name};RSVP=tru")
    assert event.match(re_attendees)
    #MGS- check the place
    assert event.match(Regexp.escape("LOCATION:Bob's Donuts - 1621 Polk St. San Francisco\\, CA 94109"))
    assert /GEO:\d+/ =~ event
  end
end