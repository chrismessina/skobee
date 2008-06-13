require File.dirname(__FILE__) + '/watir_test_helper'

class PlanTest < Test::Unit::TestCase
    include Watir

    def setup
      super
    end

    def gotoPage( a )
       $ie.goto($htmlRoot + a)
    end

#    def test_calendar_control
#      login_user("existingbob")
#      #goto create plan page
#      gotoPage("plans/new?planner_id=2")
#
#      cal_div = $ie.div(:id, "hiddendate_planner")
#      #the planner div shouldn't be visible, unless you click the link to enable it
#      #assert !cal_div.visible?
#
#      #select specific date to show the date textfield
#      $ie.select_list(:id , "dateperiod").select("Specific Date")
#      $ie.select_list(:id, "dateperiod").fireEvent("onchange")
#
#
#      $ie.link(:id, "hiddendate_link").click
#
#      assert cal_div.visible?
#
#      now = Time.now
#      #look for month string
#      assert_match %r{#{now.strftime("%B")}}, cal_div.text.strip
#
#      #click on the first day of the month
#      $ie.link(:id, "day1").click
#
#      #the chosen date should be the current month
#      assert_equal $ie.text_field(:id, "date_month").value, now.month.to_s
#      assert_equal $ie.text_field(:id, "date_year").value, now.year.to_s
#      #MGS- we're choosing the 1st day of the month
#      assert_equal $ie.text_field(:id, "date_day").value, "1"
#
#    end
#
#    def test_who_autocomplete
#      login_user("existingbob")
#      gotoPage("plans/new?planner_id=2")
#
#      assert($ie.text_field(:id, 'plan_who').exists?)
#
#      assert_autocomplete('bob', 'bo', 'plan_who_div', 'plan_who', true)
#
#      #click on bob
#      $ie.send_keys("{DOWN}")
#      $ie.send_keys("{ENTER}")
#      #puts $ie.html()
#      sleep 1
#      #make sure bob is selected
#      #assert_equal "bob", $ie.text_field(:id, "contacts_list").value
#
#      #bob added to contact list
#      assert $ie.contains_text("bob")
#
#      #KS- check that the autocomplete box DOESN'T contain users that are not
#      #in the user's contact list
#      assert_autocomplete('fri', 'friend_1_of_user', 'plan_who_div', 'plan_who', false)
#    end
#
#   def test_place_autocomplete
#      login_user("existingbob")
#      gotoPage("plans/new?planner_id=2")
#
#      assert($ie.text_field(:id, 'place_name').exists?)
#
#      assert_autocomplete("Magic Dragon Chinese", 'magi', 'place_list_auto_complete', 'place_name', true)
#
#      #click on magic dragon
#      $ie.send_keys("{DOWN}")
#      $ie.send_keys("{ENTER}")
#      #puts $ie.html()
#      sleep 1
#      #make sure m.d.c. is selected
#      #assert_equal "bob", $ie.text_field(:id, "contacts_list").value
#
#      #magic dragon chinese selected as place
#      assert $ie.contains_text("Magic Dragon Chinese")
#    end
#
#    def test_accepting_plan
#      #MGS- login as existingbob, create a plan with bob as an invitee
#      #then login as bob, check that you can see that plan
#      #accept that plan, check that it shows up as accepted in your planner
#      #then reject that plan, check that it disappears from your planner
#      login_user("existingbob")
#
#      gotoPage("plans/new?planner_id=2")
#
#      #create a new plan and invite bob
#      $ie.text_field(:id, "plan_name").set("scrubby rise plan for bob")
#      $ie.text_field(:id, "plan_who").set("bob")
#
#      #select specific date to show the date textfield
#      $ie.select_list(:id , "dateperiod").select("Specific Date")
#      $ie.select_list(:id, "dateperiod").fireEvent("onchange")
#
#      now = Time.now
#      $ie.text_field(:id, "date_year").set("#{now.year}")
#      $ie.text_field(:id, "date_month").set("#{now.month}")
#      $ie.text_field(:id, "date_day").set("#{now.day}")
#
#      $ie.button(:name, "Save Plan").click
#
#      sleep 4
#      #plan must have been created
#      assert_equal($ie.url, $htmlRoot + "planners/schedule_details")
#      #assert($ie.contains_text("Plan was successfully created"))
#
#      login_user("bob")
#
#      gotoPage("planners/schedule_details/1")
#      assert($ie.contains_text("scrubby rise plan for bob"))
#      #look for the plan id in the html
#      #should look something like this: /planners/accept_plan/1?pln_id=18
#      #take the 2nd half after the ='s as the plan id
#      #ghetto but functional
#      spliturl = $ie.link(:text, "I'll Be There").href.split('=')
#
#      gotoPage("plans/show/" +spliturl[1])
#
#
#   #MC 0 MGS TODO - need to align test to new anchor-tag based rsvp...commenting stuff out for now
#      #value of 1 is Plan::STATUS_INVITED
#      #assert($ie.select_list(:id , "rsvp").value, 1)
#
#      #now change the status to 2 => Plan::STATUS_ACCEPTED
#      #$ie.select_list(:id , "rsvp").select("I'll Be There")
#      #$ie.select_list(:id, "rsvp").fireEvent("onchange")
#      #sleep 2  #time for ajax to save status change
#      #go to schedule details
#      #gotoPage("planners/schedule_details/1")
#      #shouldn't see "I'll Be There" link
#      #assert(!$ie.contains_text("I'll Be There"))
#
#      #now go to plan and change status back to i'm out
#      #gotoPage("plans/show/" +spliturl[1])
#
#
#      #value of 2 is Plan::STATUS_ACCEPTED
#      #assert($ie.select_list(:id , "rsvp").value, 2)
#
#      #now change the status to 3 => Plan::STATUS_REJECTED
#      #$ie.select_list(:id , "rsvp").select("I'm Out")
#      #$ie.select_list(:id, "rsvp").fireEvent("onchange")
#      #sleep 2  #time for ajax to save status change
#      #go to schedule details
#      #gotoPage("planners/schedule_details/1")
#      #shouldnt see plan anymore
#      #assert(!$ie.contains_text("scrubby rise plan for bob"))
#
#      #noiiice!!!!
#
#    end
#
#    def test_place_search
#      #MGS= test the ajax search
#      login_user("existingbob")
#      gotoPage("plans/new?planner_id=2")
#
#      $ie.text_field(:id, "place_name").set("a")
#      $ie.link(:id, "advanced-find").click
#
#      $ie.text_field(:id, "location").set("604 Mission St. San Francisco, CA 94109")
#      $ie.link(:id, "search-places").click
#
#      sleep 2
#
#      assert $ie.contains_text("I am a really good place to search for, and abcde")
#
#      $ie.link(:id, "find-place-4").click
#
#      assert $ie.text_field(:id, "place_name").getContents().include?("I am a really good place to search for")
#    end


end
