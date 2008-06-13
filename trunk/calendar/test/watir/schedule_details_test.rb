require File.dirname(__FILE__) + '/watir_test_helper'

class ScheduleDetailsTest < Test::Unit::TestCase
  include Watir

  #MGS- event name EVTings
  EVT1 = ["Dinner @ Del Taco","Dinner"]
  EVT2 = ["Lunch at Chevys","Lunch"]
  EVT3 = ["Breakfast @ Pancho's","Breakfast"]
  EVT4 = ["Morning meeting with scrubs","Morning"]
  EVT5 = ["All day travel","All Day"]
  EVT6 = ["Lunch at Chevys","Lunch"]
  EVT7 = ["Breakfast","Breakfast"]
  EVT8 = ["All day crap","All Day"]

  def setup
    super
    login_user("existingbob")
    gotoPage("planners/schedule_details/2")
  end

  def gotoPage( a )
    $ie.goto($htmlRoot + a)
  end

  def test_autocomplete
    assert($ie.text_field(:id, 'contacts_list').exists?)

    assert_autocomplete('bob', 'bo', 'contacts_list_auto_complete', 'contacts_list', true)

    #click on bob
    $ie.send_keys("{DOWN}")
    $ie.send_keys("{ENTER}")
    #puts $ie.html()
    sleep 1
    #make sure bob is selected
    #assert_equal "bob", $ie.text_field(:id, "contacts_list").value

    #bob added to contact list
    assert $ie.contains_text("bob")

    #KS- check that the autocomplete box DOESN'T contain users that are not
    #in the user's contact list
    assert_autocomplete('use', 'friend_1_of_user', 'contacts_list_auto_complete', 'contacts_list', false)
  end


  def test_add_friends_plan
    assert $ie.contains_text("user_with_friends")
    #MES- TODO: These elements are no longer divs.  Now, they
    # are 'dt's.  Unfortunately, it doesn't seem like Watir can find/click on
    # a dt element.  See readme.rb in http://wtr.rubyforge.org/rdoc/
    #
    #      assert $ie.element(:id, "check_contact_7").exists?
    #      $ie.div(:id, "check_contact_7").fireEvent("onclick")
    #
    #      sleep 2
    #      assert $ie.div(:id, "decheck_contact_7").exists?
    #
    #
    #      #MGS- make sure that your friend's plans were added to your page
    #      assert $ie.contains_text("Another plan that occurs in the future")
    #
    #
    #      assert $ie.div(:id, "insert-11").exists?
    #      $ie.div(:id, "insert-11").fireEvent("onclick")
    #
    #      sleep 2
    #
    #      #MGS- it inserted the plans
    #      assert $ie.div(:id, "plan-list-11").exists?
    #      assert !$ie.div(:id, "insert-11").exists?

  end


end