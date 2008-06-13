require File.dirname(__FILE__) + '/../../test_helper'
require 'mailman'
require 'tmail'

# Re-raise errors caught by the controller.
class Mailman; def rescue_action(e) raise e end; end

class MailmanTest < Test::Unit::TestCase

  fixtures :users, :plans, :planners, :planners_plans, :places, :emails, :user_atts, :plan_changes

  def setup
    #MES- Here's a summary of what the relevant emails contain.  Hopefully, this is
    # easier to read than the raw emails.
    #
    #Email 1:
    #
    #From: kavin620@hotmail.com
    #To: kavin620@gmail.com, kavin.stewart@gmail.com
    #what: castro halloween mayhem
    #where: castro
    #when: next week
    #
    #
    #Email 2:
    #
    #In-Reply-To: Email 1
    #From: kavin620@gmail.com
    #To: kavin620@hotmail.com, kavin.stewart@gmail.com
    #where: my place
    #address: 4209 Howe St., Oakland, CA, 94611
    #when: next thursday
    #
    #
    #Email 3:
    #
    #In-Reply-To: email 2
    #From: kavin620@hotmail.com
    #To: kavin620@gmail.com, kavin.stewart@gmail.com
    #when: next thursday evening
    #
    #
    #Email 4:
    #
    #In-Reply-To: email 3
    #From: kavin620@gmail.com
    #To: kavin620@hotmail.com, kavin.stewart@gmail.com, kavin620@yahoo.com
    #
    #
    #Email 5:
    #
    #In-Reply-To: email 4
    #From: kavin620@yahoo.com
    #To: kavin620@gmail.com, kavin620@hotmail.com, kavin.stewart@gmail.com, kavin620@yahoo.com
    #where: kavin's hut
    #
    #
    #Email 6:
    #
    #In-Reply-To: email 4
    #From: kavin620@hotmail.com
    #To: kavin620@gmail.com, kavin.stewart@gmail.com, kavin620@yahoo.com
    #where: other kavin's hut
    #
    #
    #Email 7:
    #
    #In-Reply-To: email 6
    #From: kavin620@gmail.com
    #To: kavin620@hotmail.com, kavin.stewart@gmail.com, kavin620@yahoo.com
    #
    #when: Dinner Next Week
    #address:115 Cyril Magnin St, San Francisco, CA, 94102
    #
    #
    #Email 8:
    #
    #In-Reply-To: email 7
    #From: kavin.stewart@gmail.com
    #To: kavin620@gmail.com, kavin620@hotmail.com, kavin620@yahoo.com
    #
    #when: 12/6/2005 @ 8pm
    #where: China Bistro Chinese Restaurant
    #
    #
    #Email 9:
    #
    #In-Reply-To: email 8
    #From: kavin620@yahoo.com
    #To: kavin.stewart@gmail.com, kavin620@hotmail.com, kavin620@yahoo.com
    #
    #when: Dinner, 12/6/2005
    #where: Bamboo House Chinese Rstrnt
    #address: 320 N Midway Dr, Escondido, CA
  
    @email1_string = file_to_string(File.dirname(__FILE__) + '/../../data/castro-email1.txt')
    @email2_string = file_to_string(File.dirname(__FILE__) + '/../../data/castro-email2.txt')
    @email3_string = file_to_string(File.dirname(__FILE__) + '/../../data/castro-email3.txt')
    @email4_string = file_to_string(File.dirname(__FILE__) + '/../../data/castro-email4.txt')
    @email5_string = file_to_string(File.dirname(__FILE__) + '/../../data/castro-email5.txt')
    @email6_string = file_to_string(File.dirname(__FILE__) + '/../../data/castro-email6.txt')
    @email7_string = file_to_string(File.dirname(__FILE__) + '/../../data/castro-email7.txt')
    @email8_string = file_to_string(File.dirname(__FILE__) + '/../../data/castro-email8.txt')
    @email9_string = file_to_string(File.dirname(__FILE__) + '/../../data/castro-email9.txt')
    @email10_string = file_to_string(File.dirname(__FILE__) + '/../../data/castro-email10.txt')
    
    @fresh_email_string1 = file_to_string(File.dirname(__FILE__) + '/../../data/fresh-email1.txt')
    @fresh_email_string2 = file_to_string(File.dirname(__FILE__) + '/../../data/fresh-email2.txt')
    
    @multiple_recipients_string = file_to_string(File.dirname(__FILE__) + '/../../data/multiple_invitee_email.txt')
    
    @invitee_not_in_system_string = file_to_string(File.dirname(__FILE__) + '/../../data/invitee_not_in_system_email.txt')
    
    @email1 = TMail::Mail.parse(@email1_string)
    @email2 = TMail::Mail.parse(@email2_string)
    @email3 = TMail::Mail.parse(@email3_string)
    @email4 = TMail::Mail.parse(@email4_string)
    @email5 = TMail::Mail.parse(@email5_string)
    @email6 = TMail::Mail.parse(@email6_string)
    @email7 = TMail::Mail.parse(@email7_string)
    @email8 = TMail::Mail.parse(@email8_string)
    @email9 = TMail::Mail.parse(@email9_string)
    
    @fresh_email1 = TMail::Mail.parse(@fresh_email_string1)
    @fresh_email2 = TMail::Mail.parse(@fresh_email_string2)
    
    @multiple_recipients_email = TMail::Mail.parse(@multiple_recipients_string)
    
    @invitee_not_in_system_email = TMail::Mail.parse(@invitee_not_in_system_string)
    
    @sent_emails = ActionMailer::Base.deliveries
    @sent_emails.clear
    
    #MES- The tests of receiving emails from files require a source folder and a 
    # destination folder.  Make them now, if needed
    @source_folder_name = File.expand_path(File.dirname(__FILE__) + '/../../source_emails')
    @dest_folder_name = File.expand_path(File.dirname(__FILE__) + '/../../handled_emails')
    @file_test_folder_name = File.expand_path(File.dirname(__FILE__) + '/../../emails_for_file_test')
  end
  
  #KS- test that when it's not ok to create new accounts, email event creation
  #still works but that new accounts are not created for unrecognized emails.
  def test_user_create_mode_off
    original_value = MAX_USER_GENERATION
    begin
      Object.const_set('MAX_USER_GENERATION', 0)
      
      bob = User.find(1)
      existingbob = User.find(2)
      longbob = User.find(3)
      initial_bob_plan_count = bob.planner.plans.length
      initial_existingbob_plan_count = existingbob.planner.plans.length
      initial_longbob_plan_count = longbob.planner.plans.length
      
      Mailman.receive(@invitee_not_in_system_string)
      
      bob = User.find(1)
      existingbob = User.find(2)
      longbob = User.find(3)
      assert_equal initial_bob_plan_count + 1, bob.planner.plans.length
      assert_equal initial_existingbob_plan_count + 1, existingbob.planner.plans.length
      assert_equal initial_longbob_plan_count, longbob.planner.plans.length
      
      #KS- make sure a user was NOT created for kavin620@yahoo.com
      assert_nil User.find_by_string('kavin620@yahoo.com')
    ensure
      Object.const_set('MAX_USER_GENERATION', original_value)
    end
  end
  
  def test_user_create_mode_on
    original_value = MAX_USER_GENERATION
    begin
      Object.const_set('MAX_USER_GENERATION', 5)
      
      bob = User.find(1)
      existingbob = User.find(2)
      longbob = User.find(3)
      initial_bob_plan_count = bob.planner.plans.length
      initial_existingbob_plan_count = existingbob.planner.plans.length
      initial_longbob_plan_count = longbob.planner.plans.length
      
      Mailman.receive(@invitee_not_in_system_string)
      
      bob = User.find(1)
      existingbob = User.find(2)
      longbob = User.find(3)
      assert_equal initial_bob_plan_count + 1, bob.planner.plans.length
      assert_equal initial_existingbob_plan_count + 1, existingbob.planner.plans.length
      assert_equal initial_longbob_plan_count, longbob.planner.plans.length
      
      #KS- make sure a user WAS created for kavin620@yahoo.com
      assert_not_nil User.find_by_string('kavin620@yahoo.com')
    ensure
      Object.const_set('MAX_USER_GENERATION', original_value)
    end
  end

  #KS- this test is to ensure that the email parsing / event creation works when
  #there are multiple recipients. in production we noticed that if we sent an
  #email to someone and CC'ed planner@skobee that a plan would not get created.
  #it only appears to work if skobee is the only recipient of the email.
  #UPDATE: it looks like this test passes on my dev machine. i have run the failing
  #email against the same db on my dev machine and it also works. i'll leave this
  #test in anyways just for kicks.
  def test_multiple_recipients
    bob = User.find(1)
    existingbob = User.find(2)
    longbob = User.find(3)
    initial_bob_plan_count = bob.planner.plans.length
    initial_existingbob_plan_count = existingbob.planner.plans.length
    initial_longbob_plan_count = longbob.planner.plans.length
    
    Mailman.receive(@multiple_recipients_string)
    
    bob = User.find(1)
    existingbob = User.find(2)
    longbob = User.find(3)
    assert_equal initial_bob_plan_count + 1, bob.planner.plans.length
    assert_equal initial_existingbob_plan_count + 1, existingbob.planner.plans.length
    assert_equal initial_longbob_plan_count, longbob.planner.plans.length
  end  

  def test_receive
    tz = TZInfo::Timezone.get('America/Tijuana')
    usr = users(:kavin620_at_hotmail_dot_com)
    #first test a sequence of emails that creates and modifies a single plan
    #there should be no plan for any of these emails before we call receive
    assert_equal 0, Plan.find_by_email(@email1, usr).length
    assert_equal 0, Plan.find_by_email(@email2, usr).length
    assert_equal 0, Plan.find_by_email(@email3, usr).length
    assert_equal 0, Plan.find_by_email(@email4, usr).length
    assert_equal 0, Plan.find_by_email(@email5, usr).length
    assert_equal 0, Plan.find_by_email(@email6, usr).length
    assert_equal 0, Plan.find_by_email(@fresh_email1, usr).length
    assert_equal 0, Plan.find_by_email(@fresh_email2, usr).length
    
    
    
    #assert that receiving @email1 created a plan in the db that can be found 
    #via @email2
    Mailman.receive(@email1_string)
    retrieved_plan1 = Plan.find_by_email(@email2, usr)[0]
    assert_not_nil retrieved_plan1
    assert_equal 'test event1', retrieved_plan1.email_ids.detect { |i| i.email_id == @email2.in_reply_to[0] }.canonical_subject
    assert_equal 1, @sent_emails.size, 'Wrong number of confirmation emails sent'
    
    #MES- The invitees for the plan should be kavin620@hotmail.com (confirmed),
    #  kavin620@gmail.com (invited), and kavin.stewart@gmail.com (invited)
    k_hotmail = User.find_by_email('kavin620@hotmail.com').planner
    k_gmail = User.find_by_email('kavin620@gmail.com').planner
    k_s_gmail = User.find_by_email('kavin.stewart@gmail.com').planner
    
    #MES- kavin620@hotmail.com sent the email, so he should be confirmed
    # kavin620@gmail.com and kavin.stewart@gmail.com were invited, so their status should be "invited"
    assert_statuses retrieved_plan1, 
      { k_hotmail => Plan::STATUS_ACCEPTED, k_gmail => Plan::STATUS_INVITED, k_s_gmail => Plan::STATUS_INVITED }
      
    #MES- kavin620@hotmail.com owns the plan, since he made it
    # The others are invitees
    assert_owners retrieved_plan1, 
      { k_hotmail => Plan::OWNERSHIP_OWNER, k_gmail => Plan::OWNERSHIP_INVITEE, k_s_gmail => Plan::OWNERSHIP_INVITEE, }
    #MES- The location should be 'castro'
    assert_equal 'castro', retrieved_plan1.place.name
    #MES- The title for the plan should be the subject of the email
    assert_equal 'castro halloween mayhem', retrieved_plan1.name
    #MES- The time should be 'next week', at the default time
    assert_equal Plan::DATE_DESCRIPTION_NEXT_WEEK, retrieved_plan1.dateperiod(tz)
    assert_equal Plan::DEFAULT_TIME, retrieved_plan1.timeperiod
    
    
    
    #assert that receiving @email2 created a plan in the db that can be found 
    #via @email3
    Mailman.receive(@email2_string)
    retrieved_plan2 = Plan.find_by_email(@email3, usr)[0]
    assert_not_nil retrieved_plan2
    assert_equal 'test event1', retrieved_plan2.email_ids.detect{ |i| i.email_id == @email3.in_reply_to[0] }.canonical_subject
    #MES- Receiving more email commands should NOT generate more outgoing email
    assert_equal 1, @sent_emails.size, 'Wrong number of confirmation emails sent'
    
    #MES- Applying email2 should perform the following changes:
    # kavin620@gmail.com is now confirmed, since he replied
    # The place should be 'my place', with address '4209 Howe St., Oakland, CA, 94611'
    # The time should be 'next thursday'
    assert_statuses retrieved_plan2, 
      { k_hotmail => Plan::STATUS_ACCEPTED, k_gmail => Plan::STATUS_ACCEPTED, k_s_gmail => Plan::STATUS_INVITED }
    #MES- Ownership should NOT have changed
    assert_owners retrieved_plan2,
      { k_hotmail => Plan::OWNERSHIP_OWNER, k_gmail => Plan::OWNERSHIP_INVITEE, k_s_gmail => Plan::OWNERSHIP_INVITEE, }
    #MES- The location should be 'my place'
    assert_equal 'my place', retrieved_plan2.place.name
    assert_equal '4209 Howe St., Oakland, CA, 94611', retrieved_plan2.place.location    
    #MES- The what should NOT have changed
    assert_equal 'castro halloween mayhem', retrieved_plan2.name
    #MES- The time should be a thursday, at the default time
    assert_equal 4, retrieved_plan2.start_in_tz(tz).wday
    assert_equal retrieved_plan2.start, retrieved_plan2.fuzzy_start
    assert_equal Plan::DEFAULT_TIME, retrieved_plan2.timeperiod
    #MES- Since we changed the time and the place and someone RSVPd, there should be five new changes.
    # 2 for the time change, 2 for the place change, and 1 for the RSVP change.  There should ALREADY
    # be one for the pre-existing RSVP change, so there should be 6 total.
    assert_equal 6, retrieved_plan2.plan_changes.length
    
    
    
    
    #assert that receiving @email3 created a plan in the db that can be found 
    #via @email4
    Mailman.receive(@email3_string)
    retrieved_plan3 = Plan.find_by_email(@email4, usr)[0]
    assert_not_nil retrieved_plan3
    assert_equal 'Test event1', retrieved_plan3.email_ids.detect{ |i| i.email_id == @email4.in_reply_to[0] }.canonical_subject
    
    #MES- Applying email3 should perform the following changes:    
    # kavin620@hotmail.com is now confirmed, since he replied
    # The time should be 'next thursday evening'
    assert_statuses retrieved_plan3, 
      { k_hotmail => Plan::STATUS_ACCEPTED, k_gmail => Plan::STATUS_ACCEPTED, k_s_gmail => Plan::STATUS_INVITED }
    #MES- Ownership should NOT have changed
    assert_owners retrieved_plan3,
      { k_hotmail => Plan::OWNERSHIP_OWNER, k_gmail => Plan::OWNERSHIP_INVITEE, k_s_gmail => Plan::OWNERSHIP_INVITEE, }
    #MES- The location should NOT have changed
    assert_equal 'my place', retrieved_plan2.place.name
    #MES- The what should NOT have changed
    assert_equal 'castro halloween mayhem', retrieved_plan3.name
    #MES- The time should be a thursday, in the evening
    assert_equal 5, retrieved_plan3.start.wday
    assert_equal retrieved_plan3.start, retrieved_plan3.fuzzy_start
    assert_equal Plan::TIME_DESCRIPTION_EVENING, retrieved_plan3.timeperiod
    #MES- Since we changed something, there should be more revertable changes
    assert_equal 8, retrieved_plan3.plan_changes.length
    
    
    
    
    #assert that receiving @email4 created a plan in the db that can be found 
    #via @email5
    Mailman.receive(@email4_string)
    retrieved_plan4 = Plan.find_by_email(@email5, usr)[0]
    assert_not_nil retrieved_plan4
    assert retrieved_plan4.email_ids.detect{ |i| i.email_id == @email5.in_reply_to[0] }
    
    #MES- Applying email4 should perform the following changes:
    # kavin620@gmail.com is now confirmed, since he replied
    # kavin620@yahoo.com is a NEW user, and is invited
    k_yahoo = User.find_by_email('kavin620@yahoo.com').planner
    assert_statuses retrieved_plan4, 
      { k_hotmail => Plan::STATUS_ACCEPTED, k_gmail => Plan::STATUS_ACCEPTED, k_s_gmail => Plan::STATUS_INVITED, k_yahoo => Plan::STATUS_INVITED }
    #MES- The new user is NOT an owner
    assert_owners retrieved_plan4,
      { k_hotmail => Plan::OWNERSHIP_OWNER, k_gmail => Plan::OWNERSHIP_INVITEE, k_s_gmail => Plan::OWNERSHIP_INVITEE, k_yahoo => Plan::OWNERSHIP_INVITEE, }
    #MES- The location should NOT have changed
    assert_equal 'my place', retrieved_plan2.place.name
    #MES- The what should NOT have changed
    assert_equal 'castro halloween mayhem', retrieved_plan4.name
    #MES- The time should not have changed
    assert_equal 5, retrieved_plan4.start.wday
    assert_equal retrieved_plan4.start, retrieved_plan4.fuzzy_start
    assert_equal Plan::TIME_DESCRIPTION_EVENING, retrieved_plan4.timeperiod
    #MES- We did not change anything about the plan, so the number of revertable changes should still be the same
    assert_equal 9, retrieved_plan4.plan_changes.length
    #MGS- assert that the new user for kavin620@yahoo.com has a contact
    assert User.find_by_email('kavin620@yahoo.com').friend_contacts.include?(User.find_by_email('kavin620@gmail.com'))

    #now, we'll create a fresh plan and make sure it can be retrieved via a
    #reply email
    Mailman.receive(@fresh_email_string1)
    retrieved_plan5 = Plan.find_by_email(@fresh_email2, usr)[0]
    assert_not_nil retrieved_plan5
    assert retrieved_plan5.email_ids.detect{|i| i.email_id == @fresh_email2.in_reply_to[0]}
    
    #now receive one more email from the initial plan thread and make sure that
    #it can be found via a reply to that email
    #MES- On email 5- the sender did NOT cc kavin620@hotmail.com, so Skobee should
    # notify that user that there was a change to the plan, but not OTHER users, since
    # they ARE on the original email
    assert_equal 2, @sent_emails.size, 'Bad initial conditions'    
    Mailman.receive(@email5_string)
    retrieved_plan6 = Plan.find_by_email(@email6, usr)[0]
    assert_not_nil retrieved_plan6
    assert retrieved_plan6.email_ids.detect{ |i| i.email_id == @email6.in_reply_to[0] }
    assert_equal 3, @sent_emails.size, 'Confirmation email not sent to user who was not on distro list'
    assert_equal 'kavin620@hotmail.com', @sent_emails[2].to[0]
    
    #MES- Applying email 5 should perform the following changes:
    # kavin620@yahoo.com has rejected the plan (and changed the place!)
    #  The place is "kavin's hut"
    assert_statuses retrieved_plan6,
      { k_hotmail => Plan::STATUS_ACCEPTED, k_gmail => Plan::STATUS_ACCEPTED, k_s_gmail => Plan::STATUS_INVITED, k_yahoo => Plan::STATUS_REJECTED, }
    #MES- Ownership should NOT have changed
    assert_owners retrieved_plan6,
      { k_hotmail => Plan::OWNERSHIP_OWNER, k_gmail => Plan::OWNERSHIP_INVITEE, k_s_gmail => Plan::OWNERSHIP_INVITEE, k_yahoo => Plan::OWNERSHIP_INVITEE, }
    #MES- The location should be "kavin's hut"
    assert_equal "kavin's hut", retrieved_plan6.place.name
    #MES- The what should NOT have changed
    assert_equal 'castro halloween mayhem', retrieved_plan6.name
    #MES- The time should not have changed
    assert_equal 5, retrieved_plan6.start.wday
    assert_equal retrieved_plan6.start, retrieved_plan6.fuzzy_start
    assert_equal Plan::TIME_DESCRIPTION_EVENING, retrieved_plan6.timeperiod
    #MES- Since we changed something, there should be another revertable change
    assert_equal 11, retrieved_plan6.plan_changes.length
    
    
    
    #MES- Some other test cases- Kavin set up the previous stuff, I set up this stuff
    Mailman.receive(@email7_string)
    pln = Plan.find_by_email(@email7, usr)[0]
    assert_equal Plan::TIME_DESCRIPTION_DINNER, pln.timeperiod
    assert_equal Plan::DATE_DESCRIPTION_NEXT_WEEK, pln.dateperiod(tz)
    assert_equal places(:place_for_location_search), pln.place
    
    expected_time = Time.local(2005, 12, 6, 20, 0, 0)
    utc_time = tz.local_to_utc(expected_time) 
    Mailman.receive(@email8_string)
    pln = Plan.find_by_email(@email8, usr)[0]
    assert_equal utc_time, pln.start
    assert_equal places(:san_diego_restaurant1), pln.place
    
    expected_time = Time.local(2005, 2, 10, 13, 30, 0)
    utc_time = tz.local_to_utc(expected_time) 
    Mailman.receive(@email9_string)
    pln = Plan.find_by_email(@email9, usr)[0]
    assert_equal utc_time, pln.start    
    assert_equal places(:san_diego_restaurant2), pln.place
    
    #MES- Receive email 10.  With email 10, the plan is identified 
    # via the "to" email address, rather than via a referrer ID.
    # This tests that Plan.find_by_email can find a plan based on
    # a plan ID in the Skobee email address.
    Mailman.receive sprintf(@email10_string, EmailId.email_address_for_plan(pln.id))
    #MES- This should change the venue back to san_diego_restaurant1
    pln = Plan.find(pln.id)
    assert_equal places(:san_diego_restaurant1), pln.place
    
  end
  
  def test_status_change
    #MES- Test that the RSVP status change operators work
    plan = Mailman.receive(read_email_file('test_status_change_1.txt'))
    #MES- User bob should be confirmed, user existingbob should be invited
    bob = users(:bob)
    existingbob = users(:existingbob)
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(bob, plan)
    assert_equal Plan::STATUS_INVITED, stat_for_plan(existingbob, plan)
    
    #MES- In test_status_change_2.txt, existingbob accepts the plan
    plan = Mailman.receive(read_email_file('test_status_change_2.txt'))
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(bob, plan)
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(existingbob, plan)
    
    #MES- Let's make another email that's the same, but the body is different
    plan = Mailman.receive(read_email_file('test_status_change_2.txt').sub(/rsvp: i'm in/, "rsvp: i'm interested"))
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(bob, plan)
    assert_equal Plan::STATUS_INTERESTED, stat_for_plan(existingbob, plan)
    
    #MES- "rsvp: i'm out" should also work
    plan = Mailman.receive(read_email_file('test_status_change_2.txt').sub(/rsvp: i'm in/, "rsvp: i'm out"))
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(bob, plan)
    assert_equal Plan::STATUS_REJECTED, stat_for_plan(existingbob, plan)
    
    #MES- They should all work without the "rsvp: " prefix
    plan = Mailman.receive(read_email_file('test_status_change_2.txt').sub(/rsvp: i'm in/, "i'm in"))
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(bob, plan)
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(existingbob, plan)
    
    plan = Mailman.receive(read_email_file('test_status_change_2.txt').sub(/rsvp: i'm in/, "i'm interested"))
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(bob, plan)
    assert_equal Plan::STATUS_INTERESTED, stat_for_plan(existingbob, plan)
    
    plan = Mailman.receive(read_email_file('test_status_change_2.txt').sub(/rsvp: i'm in/, "i'm out"))
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(bob, plan)
    assert_equal Plan::STATUS_REJECTED, stat_for_plan(existingbob, plan)
    
    #MES- "I'll Be There" should be a synonym for "I'm In"
    plan = Mailman.receive(read_email_file('test_status_change_2.txt').sub(/rsvp: i'm in/, "rsvp: i'll be there"))
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(bob, plan)
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(existingbob, plan)
    plan = Mailman.receive(read_email_file('test_status_change_2.txt').sub(/rsvp: i'm in/, "i'm out"))
    plan = Mailman.receive(read_email_file('test_status_change_2.txt').sub(/rsvp: i'm in/, "i'll be there"))
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(bob, plan)
    assert_equal Plan::STATUS_ACCEPTED, stat_for_plan(existingbob, plan)
  end
  
  def stat_for_plan(user, plan)
    user.planner.plans(true).detect{|x| x.id == plan.id }.cal_pln_status.to_i
  end
  
  def test_no_plan_create_user_att
    #KS- plan found by email 2 should not exist yet
    usr = users(:kavin620_at_hotmail_dot_com)
    assert_equal 0, Plan.find_by_email(@email2, usr).length
  
    #KS- set the user's ATT_ALLOW_PLAN_CREATION_VIA_EMAIL to 0
    User.find_by_string('kavin620@hotmail.com').set_att(UserAttribute::ATT_ALLOW_PLAN_CREATION_VIA_EMAIL, 0)
  
    Mailman.receive(@email1_string)
    
    #KS- there should be no plan since we set the ATT_ALLOW_PLAN_CREATION_VIA_EMAIL to 0
    assert_equal 0, Plan.find_by_email(@email2, usr).length
  end
  
  def assert_statuses(plan, status_map)
    plan.planners.each do | cal |
      assert status_map.has_key?(cal), "Planner owned by #{cal.owner.login} does not appear in status map"
      assert_equal status_map[cal], cal.cal_pln_status.to_i, "Planner owned by #{cal.owner.login} (#{cal.owner.email}) should have status #{Plan::STATUS_NAMES[status_map[cal]]}, but has status #{Plan::STATUS_NAMES[cal.cal_pln_status.to_i]}"
    end
  end
  
  def assert_owners(plan, owner_map)
    plan.planners.each do | cal |
      assert owner_map.has_key?(cal)
      assert_equal owner_map[cal], cal.ownership.to_i
    end
  end
  
  def test_what_command
    #MES- When creating a new plan, the what command should take precedence over
    # the subject
    plan = Mailman.receive(read_email_file('test_what_command_1.txt'))
    assert_equal 'what from the body', plan.name
    
    #MES- But when there's no what command, the what should come from the subject
    plan2 = Mailman.receive(read_email_file('test_what_command_2.txt'))
    assert_equal 'what from the subject', plan2.name
    
    #MES- When editing a plan, the subject should NOT be used at all
    plan3 = Mailman.receive(read_email_file('test_what_command_3.txt'))
    assert_equal plan3.id, plan2.id
    assert_equal 'what from the subject', plan3.name
    
    #MES- But a what command should
    plan4 = Mailman.receive(read_email_file('test_what_command_4.txt'))
    assert_equal plan4.id, plan2.id
    assert_equal 'what body', plan4.name
    
  end
  
  def test_datetime_exact_string_matching
    pln = plans(:first_plan)
    Time.set_now_gmt(2006, 2, 17, 16, 23, 6) do
      today = Date.civil(2006, 2, 17)
      next_thur = Date.civil(2006, 2, 23).to_numeric_arr
      mon = Date.civil(2006, 2, 20).to_numeric_arr
      assert_datetime_exact_string_match 'Next week', pln, Plan::DATE_DESCRIPTION_NEXT_WEEK, nil
      assert_datetime_exact_string_match 'next Thursday', pln, next_thur, nil
      assert_datetime_exact_string_match 'next thursday; evening', pln, next_thur, Plan::TIME_DESCRIPTION_EVENING
      assert_datetime_exact_string_match 'evening- MON', pln, mon, Plan::TIME_DESCRIPTION_EVENING
      assert_datetime_exact_string_match 'Midday This Weekend', pln, Plan::DATE_DESCRIPTION_THIS_WEEKEND, Plan::TIME_DESCRIPTION_AFTERNOON
      assert_datetime_exact_string_match 'night', pln, nil, Plan::TIME_DESCRIPTION_EVENING
      assert_datetime_exact_string_match 'tbd', pln, Plan::DATE_DESCRIPTION_FUTURE, Plan::TIME_DESCRIPTION_ALL_DAY
      
      #MES- Make a new plan- the code acts slightly different for unsaved plans
      pln = Plan.new
      assert_datetime_exact_string_match 'Next week', pln, Plan::DATE_DESCRIPTION_NEXT_WEEK, Plan::DEFAULT_TIME
      assert_datetime_exact_string_match 'next Thursday!', pln, next_thur, Plan::DEFAULT_TIME
      assert_datetime_exact_string_match 'next thursday evening', pln, next_thur, Plan::TIME_DESCRIPTION_EVENING
      assert_datetime_exact_string_match 'evening MON', pln, mon, Plan::TIME_DESCRIPTION_EVENING
      assert_datetime_exact_string_match 'Midday This Weekend', pln, Plan::DATE_DESCRIPTION_THIS_WEEKEND, Plan::TIME_DESCRIPTION_AFTERNOON
      assert_datetime_exact_string_match 'night?', pln, Plan::DEFAULT_DATE, Plan::TIME_DESCRIPTION_EVENING
      assert_datetime_exact_string_match 'dinner next week', pln, Plan::DATE_DESCRIPTION_NEXT_WEEK, Plan::TIME_DESCRIPTION_DINNER
      assert_datetime_exact_string_match 'lunch next week', pln, Plan::DATE_DESCRIPTION_NEXT_WEEK, Plan::TIME_DESCRIPTION_LUNCH
      assert_datetime_exact_string_match 'tbd', pln, Plan::DATE_DESCRIPTION_FUTURE, Plan::TIME_DESCRIPTION_ALL_DAY
    end
  end
  
  def assert_datetime_exact_string_match(str, pln, date_val, time_val)
    res = Mailman::perform_datetime_exact_string_match(str, pln)
    assert_not_nil res
    assert_equal date_val, res[0]
    assert_equal time_val, res[1]
  end
  
  def test_datetime_fully_specified_matching
    pln = plans(:first_plan)
    today = Date.today
    next_thur = (today.next_weekday(4) + 7).to_numeric_arr
    mon = today.next_weekday(1).to_numeric_arr
    assert_datetime_fully_specified_match '8PM next week', pln, Plan::DATE_DESCRIPTION_NEXT_WEEK, [20, 0, 0]
    assert_datetime_fully_specified_match 'next week 8:30 PM', pln, Plan::DATE_DESCRIPTION_NEXT_WEEK, [20, 30, 0]
    assert_datetime_fully_specified_match '8:30 PM 12/25/2005', pln, [2005, 12, 25], [20, 30, 0]
    assert_datetime_fully_specified_match '12/25/2005 night', pln, [2005, 12, 25], Plan::TIME_DESCRIPTION_EVENING
    assert_datetime_fully_specified_match '5am this weekend', pln, Plan::DATE_DESCRIPTION_THIS_WEEKEND, [5, 0, 0]
    assert_datetime_fully_specified_match '12/6/2005 @ 8pm', pln, [2005, 12, 6], [20, 0, 0]
  end
  
  def assert_datetime_fully_specified_match(str, pln, date_val, time_val)
    res = Mailman::perform_fully_specified_datetime_match(str, pln)
    assert_not_nil res
    assert_equal date_val, res[0]
    assert_equal time_val, res[1]
  end
  
  
  def test_find_fully_specified_time
    assert_find_fully_specified_time '8 am testing', 8, 0, 'am', ' testing'
    assert_find_fully_specified_time '8am testing', 8, 0, 'am', ' testing'
    assert_find_fully_specified_time '8:30am testing', 8, 30, 'am', ' testing'
    assert_find_fully_specified_time '8:30 pm testing', 8, 30, 'pm',  ' testing'
    assert_find_fully_specified_time ' 08:30 pm testing', nil, nil, nil, nil
    assert_find_fully_specified_time '29:30 pm testing', nil, nil, nil, nil
    assert_find_fully_specified_time '8:90 pm testing', nil, nil, nil, nil
    assert_find_fully_specified_time '8:90 pmtesting', nil, nil, nil, nil
    assert_find_fully_specified_time 'testing 8:30 pm', 8, 30, 'pm', 'testing '
    assert_find_fully_specified_time 'testing 8:90 pm', nil, nil, nil, nil
    assert_find_fully_specified_time 'testing 8pm', 8, 0, 'pm', 'testing '
    assert_find_fully_specified_time 'testing8pm', nil, nil, nil, nil
    assert_find_fully_specified_time '8pm', 8, 0, 'pm', nil
  end
  
  def assert_find_fully_specified_time(str, expected_hour, expected_min, expected_meridian, expected_remainder)
    hour, min, meridian, remainder = Mailman::find_fully_specified_time(str)
    assert_equal expected_hour, hour
    assert_equal expected_min, min
    assert_equal expected_meridian, meridian
    assert_equal expected_remainder, remainder
  end
  
  def test_find_fully_specified_date
    this_year = Date.today.year
    assert_find_fully_specified_date 'test 1/7/2005', 7, 1, 2005, 'test '
    assert_find_fully_specified_date '1/7/2005 test', 7, 1, 2005, ' test'
    assert_find_fully_specified_date '1/7/2005', 7, 1, 2005, nil
    assert_find_fully_specified_date '01/7/2005', 7, 1, 2005, nil
    assert_find_fully_specified_date '1/17/2005', 17, 1, 2005, nil
    assert_find_fully_specified_date '1/07/2005', 7, 1, 2005, nil
    assert_find_fully_specified_date '01/07/2005', 7, 1, 2005, nil
    assert_find_fully_specified_date '13/07/2005', nil, nil, nil, nil
    assert_find_fully_specified_date '01/07/05', 7, 1, 2005, nil
    assert_find_fully_specified_date 'test 01/07/05', 7, 1, 2005, 'test '
    assert_find_fully_specified_date '01/07/05 test', 7, 1, 2005, ' test'
    assert_find_fully_specified_date '1/07/2105', nil, nil, nil, nil
    assert_find_fully_specified_date '1/07/1805', nil, nil, nil, nil
    assert_find_fully_specified_date '1/07/1905', 7, 1, 1905, nil
    assert_find_fully_specified_date 'test 1/07/1905', 7, 1, 1905, 'test '
    assert_find_fully_specified_date '1/07/1905 test', 7, 1, 1905, ' test'
    assert_find_fully_specified_date '1/07', 7, 1, this_year, nil
    assert_find_fully_specified_date 'test 1/07', 7, 1, this_year, 'test '
    assert_find_fully_specified_date '1/07 test', 7, 1, this_year, ' test'
    
    assert_find_fully_specified_date 'test 1-7-2005', 7, 1, 2005, 'test '
    assert_find_fully_specified_date '1-7-2005 test', 7, 1, 2005, ' test'
    assert_find_fully_specified_date '1-7-2005', 7, 1, 2005, nil
    assert_find_fully_specified_date '01-7-2005', 7, 1, 2005, nil
    assert_find_fully_specified_date '1-17-2005', 17, 1, 2005, nil
    assert_find_fully_specified_date '1-07-2005', 7, 1, 2005, nil
    assert_find_fully_specified_date '01-07-2005', 7, 1, 2005, nil
    assert_find_fully_specified_date '13-07-2005', nil, nil, nil, nil
    assert_find_fully_specified_date '01-07-05', 7, 1, 2005, nil
    assert_find_fully_specified_date 'test 01-07-05', 7, 1, 2005, 'test '
    assert_find_fully_specified_date '01-07-05 test', 7, 1, 2005, ' test'
    assert_find_fully_specified_date '1-07-2105', nil, nil, nil, nil
    assert_find_fully_specified_date '1-07-1805', nil, nil, nil, nil
    assert_find_fully_specified_date '1-07-1905', 7, 1, 1905, nil
    assert_find_fully_specified_date 'test 1-07-1905', 7, 1, 1905, 'test '
    assert_find_fully_specified_date '1-07-1905 test', 7, 1, 1905, ' test'
    assert_find_fully_specified_date '1-07', 7, 1, this_year, nil
    assert_find_fully_specified_date 'test 1-07', 7, 1, this_year, 'test '
    assert_find_fully_specified_date '1-07 test', 7, 1, this_year, ' test'
  end
  
  def assert_find_fully_specified_date(str, expected_day, expected_month, expected_year, expected_remainder)
    year, month, day, remainder = Mailman::find_fully_specified_date(str)
    assert_equal expected_day, day, "Failed day for string #{str}"
    assert_equal expected_month, month, "Failed year month string #{str}"
    assert_equal expected_year, year, "Failed year for string #{str}"
    assert_equal expected_remainder, remainder, "Failed remainder for string #{str}"
  end
  
  def test_no_modify_locked_plan
  
    #MES- Make a plan
    plan1 = Mailman.receive(read_email_file('test_no_modify_locked_plan_1.txt'))
    assert_equal 'what from the subject', plan1.name
    
    #MES- We should be able to modify it
    plan2 = Mailman.receive(read_email_file('test_no_modify_locked_plan_2.txt'))
    assert_equal plan2.id, plan1.id
    assert_equal 'what body', plan2.name
    
    #MES- If we lock it, we should STILL be able to modify it, since we're the owner
    plan2.lock_status = Plan::LOCK_STATUS_OWNERS_ONLY
    plan2.save!
    
    plan3 = Mailman.receive(read_email_file('test_no_modify_locked_plan_3.txt'))
    assert_equal plan3.id, plan2.id
    assert_equal 'what body three', plan3.name
    
    #MES- But if we make the user NOT the owner, they should NOT be able to change the 
    # plan, though they can change their RSVP status
    plnr = plan3.planners[0]
    plan3.planners.update_attributes(plnr, { :ownership => Plan::OWNERSHIP_INVITEE, :cal_pln_status => Plan::STATUS_INVITED })
    plan3 = Plan.find(plan3.id)
    assert_equal Plan::STATUS_INVITED, plan3.planners.find(plnr.id).cal_pln_status.to_i
    assert_equal Plan::OWNERSHIP_INVITEE, plan3.planners.find(plnr.id).ownership.to_i
    
    plan4 = Mailman.receive(read_email_file('test_no_modify_locked_plan_4.txt'))
    assert_equal plan4.id, plan3.id
    #MES- The plan name should NOT have changed
    assert_equal 'what body three', plan4.name
    #MES- But it should be accepted
    assert_equal Plan::STATUS_ACCEPTED, plan4.planners.find(plnr.id).cal_pln_status.to_i
    
  end
  
  
  def test_detection_of_original_for_reply
    test_detection_of_original_for_reply_helper('gmail_style_response.txt')
    test_detection_of_original_for_reply_helper('yahoo_style_response.txt')
    test_detection_of_original_for_reply_helper('hotmail_style_response_no_separator.txt')
    test_detection_of_original_for_reply_helper('hotmail_style_response_horiz_separator.txt')
    test_detection_of_original_for_reply_helper('hotmail_style_response_greater_prefix.txt')
    test_detection_of_original_for_reply_helper('outlook_style_response.txt')
    test_detection_of_original_for_reply_helper('thunderbird_style_response_top.txt')
    test_detection_of_original_for_reply_helper('thunderbird_style_response_bottom.txt')
  end
  
  def test_detection_of_original_for_reply_helper(file)
    #MES- Open the relevant email file
    commands = Mailman::parse_email(open_and_parse_email_file(file))
    #MES- The "when" command is in the body of the email, but the "where" command
    # is in the original (the email that this is a reply to.)  Therefore, the
    # commands should contain WHEN, but NOT contain WHERE
    assert commands.include?(Mailman::COMMAND_WHEN), "Search for WHEN failed for file #{file}" 
    assert !commands.include?(Mailman::COMMAND_WHERE), "Search for WHERE succeeded for file #{file}" 
  end
  
  def open_and_parse_email_file(file)
    return TMail::Mail.parse(read_email_file(file))
  end
  
  def read_email_file(file)
    return file_to_string(File.dirname(__FILE__) + "/../../data/#{file}")
  end
  
  
  def test_receive_email_from_file
    setup_test_files
    
    #MES- Before running the test, there should be a file called email.1 in the source folder,
    # and there should NOT be one in the destination.
    assert File.exists?(File.join([@source_folder_name, 'email.1']))
    assert !File.exists?(File.join([@dest_folder_name, 'email.1']))
    
    Mailman.receive_email_from_file File.join([@source_folder_name, 'email.1']), @dest_folder_name
    #MES- There should be an email.1 file in the output directory.  There should NOT 
    # be an error.email.1 file.  Also, there should not be an email.1 file in the source dir.
    assert File.exists?(File.join([@dest_folder_name, 'email.1']))
    assert !File.exists?(File.join([@dest_folder_name, Mailman::EMAIL_FILE_ERROR_PREFIX + 'email.1']))
    assert !File.exists?(File.join([@source_folder_name, 'email.1']))
    
    #MES- Let's make sure the receive actually happened, in the same way
    # that we do in test_receive
    usr = users(:kavin620_at_hotmail_dot_com)
    retrieved_plan1 = Plan.find_by_email(@email2, usr)[0]
    assert_not_nil retrieved_plan1
    assert retrieved_plan1.email_ids.detect { |i| i.email_id == @email2.in_reply_to[0] }
    
    
    #MES- A garbage file should generate an error
    garbage_in_file_name = File.join([@source_folder_name, 'garbage.1'])
    garbage_out_file_name = File.join([@dest_folder_name, 'garbage.1'])
    garbage_err_file_name = File.join([@dest_folder_name, Mailman::EMAIL_FILE_ERROR_PREFIX + 'garbage.1'])
    open(garbage_in_file_name, 'w+') { | file | file.puts "This is NOT a legit email file" }
    Mailman.receive_email_from_file garbage_in_file_name, @dest_folder_name
    assert File.exists?(File.join([@dest_folder_name, 'garbage.1']))
    assert File.exists?(File.join([@dest_folder_name, Mailman::EMAIL_FILE_ERROR_PREFIX + 'garbage.1']))
    
  end
  
  
  def test_receive_multiple_emails_from_file
    #MES- This is pretty similar to test_receive_email_from_file.  However, 
    # we make sure we can handle multiple files, and that we process all of them.
    setup_test_files

    #MES- Before running the test, there should be files email.1-3 in the source folder,
    # and they should NOT be in the destination.
    assert File.exists?(File.join([@source_folder_name, 'email.1']))
    assert File.exists?(File.join([@source_folder_name, 'email.2']))
    assert File.exists?(File.join([@source_folder_name, 'email.3']))
    assert !File.exists?(File.join([@dest_folder_name, 'email.1']))
    assert !File.exists?(File.join([@dest_folder_name, 'email.2']))
    assert !File.exists?(File.join([@dest_folder_name, 'email.3']))
    Mailman.receive_emails_from_files_noloop @source_folder_name, @dest_folder_name, /^email\..*/
    
    #MES- Now the files should be in the dest, and there should not be error files
    assert !File.exists?(File.join([@source_folder_name, 'email.1']))
    assert !File.exists?(File.join([@source_folder_name, 'email.2']))
    assert !File.exists?(File.join([@source_folder_name, 'email.3']))
    assert File.exists?(File.join([@dest_folder_name, 'email.1']))
    assert File.exists?(File.join([@dest_folder_name, 'email.2']))
    assert File.exists?(File.join([@dest_folder_name, 'email.3']))
    assert !File.exists?(File.join([@dest_folder_name, 'error.email.1']))
    assert !File.exists?(File.join([@dest_folder_name, 'error.email.2']))
    assert !File.exists?(File.join([@dest_folder_name, 'error.email.3']))
  end
  
  def test_receive_email_from_file_dup_filenames
    #MES- Make sure that everything is cool even if there are duplicate file names
    setup_test_files

    #MES- Before running the test, there should be one file called email.1 in the destination folder.
    FileUtils.cp_r Dir.glob(File.join([@file_test_folder_name, '*'])), @dest_folder_name
    assert_equal 1, Dir.glob(File.join([@dest_folder_name, 'email.1*'])).length
    Mailman.receive_email_from_file File.join([@source_folder_name, 'email.1']), @dest_folder_name
    #MES- After, there should be TWO files called email.1* in the destination folder.
    assert_equal 2, Dir.glob(File.join([@dest_folder_name, 'email.1*'])).length
    
  end
  
  def setup_test_files
    #MES- Make sure that @source_folder_name and @dest_folder_name exist
    Dir.mkdir(@source_folder_name) if !File.exist?(@source_folder_name)
    Dir.mkdir(@dest_folder_name) if !File.exist?(@dest_folder_name)
    
    #MES- Remove all files from both folders
    FileUtils.rm_r Dir.glob(File.join([@source_folder_name, '*']))
    FileUtils.rm_r Dir.glob(File.join([@dest_folder_name, '*']))
    
    #MES- And copy the files from @file_test_folder_name to @source_folder_name
    FileUtils.cp_r Dir.glob(File.join([@file_test_folder_name, '*'])), @source_folder_name
  end
  
  def test_suggest_public_place
    #MES- When a user creates a plan via email, and that causes a private venue
    # to be created, the confirmation email should suggest some alternative
    # public places that might have been intended.  For example, if the user
    # types "where: Bamboo House", Skobee should say something like "Did you 
    # mean "Bamboo House Chinese Rstrnt"?
    Mailman.receive(read_email_file('sugg-public-place-email1.txt'))
    
    #MES- The body of the response email should include the string 
    #  "Bamboo House Chinese Rstrnt" as a suggestion
    assert_equal 1, @sent_emails.length
    assert @sent_emails.last.body.match(/Bamboo House Chinese Rstrnt/)
    #MES- And should include the help message
    assert @sent_emails.last.body.match(/Were you looking for one of these places/)
    
    
    #MES- Email 2 uses an exact match to a public place, so there should be no suggestions
    Mailman.receive(read_email_file('sugg-public-place-email2.txt'))
    assert_equal 2, @sent_emails.length
    assert !@sent_emails.last.body.match(/Were you looking for one of these places/)
    
    
    #MES- Email 3 is an exact match to a pre-existing private place, so
    # again there should be no suggestions
    Mailman.receive(read_email_file('sugg-public-place-email3.txt'))
    assert_equal 3, @sent_emails.length
    assert !@sent_emails.last.body.match(/Were you looking for one of these places/)
  end
  
  def test_match_email_by_subject
    #MES- Before making a plan, there should be no match
    usr = users(:kavin620_at_hotmail_dot_com)
    plans = Plan.find_by_email(open_and_parse_email_file('match_subj_1.txt'), usr)
    assert_equal 0, plans.length
    
    #MES- Make a plan based on an email, and get one match
    plan = Mailman.receive(read_email_file('match_subj_seed.txt'))
    plans = Plan.find_by_email(open_and_parse_email_file('match_subj_1.txt'), usr)
    assert_equal 1, plans.length
    assert_equal plan, plans[0]
    
    #MES- Make another plan, get two matches
    plan2 = Mailman.receive(read_email_file('match_subj_seed2.txt'))
    plans = Plan.find_by_email(open_and_parse_email_file('match_subj_1.txt'), usr)
    assert_equal 2, plans.length
    assert plans.include?(plan)
    assert plans.include?(plan2)
    
    #MES- If the subject does not match we shouldn't get any hits
    plans = Plan.find_by_email(open_and_parse_email_file('match_subj_2.txt'), usr)
    assert_equal 0, plans.length
    
    #MES- If we receive an email that matches more than one plan, we should get a 
    # notification email
    assert_equal  2, @sent_emails.length
    plan3 = Mailman.receive(read_email_file('match_subj_1.txt'))
    assert_nil plan3
    assert_equal 3, @sent_emails.length
    #MES- Since this email has a subject that starts with 'RE: ', the subject
    # of the sent email should match the subject of the original
    assert_equal open_and_parse_email_file('match_subj_1.txt').subject, @sent_emails[2].subject
    
    #MES- Same test, but with a subject that does NOT start with 'RE: '
    plan4 = Mailman.receive(read_email_file('match_subj_3.txt'))
    assert_nil plan4
    assert_equal 4, @sent_emails.length
    assert_equal 'Re: ' + open_and_parse_email_file('match_subj_3.txt').subject, @sent_emails[3].subject
    
    #MES- Since Exchange sucks, the codepath is a little different for Exchange.
    #MES- For Exchange, we'll do subject matching if the subject starts with "RE: "
    # regardless of whether the In-Reply-To and References headers are there.
    plans = Plan.find_by_email(open_and_parse_email_file('match_subj_4.txt'), usr)
    assert_equal 2, plans.length
    assert plans.include?(plan)
    assert plans.include?(plan2)
    #MES- If the subject does NOT start with 're', then we don't do matching
    plans = Plan.find_by_email(open_and_parse_email_file('match_subj_5.txt'), usr)
    assert_equal 0, plans.length
    
  end
  
  def test_delete_file_on_shutdown
    folder = File.dirname(__FILE__) + "/../../data"
    sd_file_name = folder + '/shutdown'
    #MES- Create a shutdown file
    sd_file = File.new(sd_file_name, 'w+')
    sd_file.close
    sd_file = nil
    assert File.exists?(sd_file_name)
    #MES- Start the mailman- it should immediately shut down and delete the file
    Mailman.receive_emails_from_files(folder, folder, "not_likely_to_exist")
    #MES- The shutdown file should be deleted
    assert !File.exists?(sd_file_name)
  end
  
  def test_pingback
    @sent_emails.clear
    Mailman.receive(read_email_file('pingback_1.txt'))
    assert_equal 1, @sent_emails.length
    assert_equal 'randomemail@randomserver.com', @sent_emails[0].to[0]
    Mailman.receive(read_email_file('pingback_2.txt'))
    assert_equal 2, @sent_emails.length
    assert_equal 'randomemail@randomserver.com', @sent_emails[1].to[0]
  end
  
  def test_bug_909
    #MES- In bug 909, a "when" of a plain date (no time) causes Mailman to throw.
    # This would also happen with a bare time (no date.)
    tz = TZInfo::Timezone.get('America/Tijuana')
    plan = Mailman.receive(read_email_file('bug_909_1.txt'))
    assert_equal Plan::TIME_DESCRIPTION_ALL_DAY, plan.timeperiod
    plan = Mailman.receive(read_email_file('bug_909_2.txt'))
    assert_equal Plan::DATE_DESCRIPTION_FUTURE, plan.dateperiod(tz)
  end
  
  def test_bug_910
    #MES- This particular email was having problems with decode.
    # See ticket 910, and the comments on plaintext_body.
    mail = TMail::Mail.parse(read_email_file('marks_bad_email.txt'))
    expected = <<END_OF_STRING

 yo-



I know the keyboardist in this band midstates....this was the band I went to
see after the superbowl....they're good...put on a good show and are playing
a cool dive bar for cheap...


I'm going to go see them and I think you guys should too....


when: 3/30/06
where: Hemlock Tavern


http://www.midstatesmusic.com
http://www.hemlocktavern.com/prog_guide.php?adate_id=3D2006-03-30


mattis- you'll be pumped to know that they're charting on woxy right now...


END_OF_STRING
    assert_equal expected, mail.plaintext_body
    
    plan = Mailman.receive(read_email_file('marks_bad_email.txt'))
    assert_equal 'Hemlock Tavern', plan.place.name
    
    #MES- What if there ISN'T a plaintext body?
    plan = Mailman.receive(read_email_file('no_plaintext.txt'))
    
    #MES- Make sure that base64 encoded can still be decode correctly
    mail = TMail::Mail.parse(read_email_file('base64encoded.txt'))
    expected = <<END_OF_STRING
LOTTO.NL,
2391 Beds 152 Koningin Julianaplein 21,
Den Haag, the Netherlands.
(Lotto affiliate with Subscriber Agents).
From: Susan Console
(Lottery Coordinator)
Website: www.lotto.nl

Sir/Madam,

CONGRATULATIONS!!!!!

We are pleased to inform you of the result of the Lotto NL Winners International programs held on the 27th,  Febuary, 2006.  Your e-mail address attached to ticket #: 00903228100 with prize # 778009/UK 
drew €1,000,000.00 which was first in the 2ndclass of the draws. You are to receive €1,000,000.00 (One Million Euros). Because of mix up in cash pay-outs, we ask that you keep your winning information 
confidential until your money (€1,000,000.00) has been fully remitted to you by our accredited pay-point bank. This measure must be adhere to avoid loss of your cash prize - winners of our cash prizes are 
advised to adhere to these instructions to forestall the abuse of this program by other participants. It's important to note that this draws were conducted formally and winners are selected through an internet 
ballot system from 60,000 individual and companies e-mail addresses - the draws are conducted around the worldthrough our internet based ballot system. The promotion is sponsored and promoted Lotto NL. 
We congratulate you once again. We hope you will use part of it in our next draws; the jackpot winning is €85million.  Remember, all winning must be claimed not later than 20 days. After this date all unclaimed 
cash prize will be forfeited and included in the next sweepstake.  Please, in order to avoid unnecessary delays and complications remember to quote personal and winning numbers in all correspondence with us. 

Congratulations once again from all members of Lotto NL. 

Thank you for being part of our promotional program.

For immediate release of your cash prize to you, please kindly contact our Paying Bank (Chartered Finance & Securities Den Haag.)

Send them the following:
(i)   Your names,
(ii) Contact telephone and fax numbers
(iii) Contact Address
(iv) Your winning numbers
(v) Quote amount won.

Contact person: Mr. Felix Peterson
E-mail:  charteredfsb@netscape.net
Tel:  +31 643 178 404

Congratulations once again.
Yours in service,
Susan Console
Web Site: www.lotto.nl
END_OF_STRING
    expected.gsub!("\n", "\r\n")
    assert_equal expected, mail.plaintext_body
    
    #MES- Test some other random quoted-printable emails, since we changed the decoding
    # of quoted printable emails significantly
    mail = TMail::Mail.parse(read_email_file('quoted-printable-1.txt'))
    expected = <<END_OF_STRING
Hey let's get together

when: lunch next week
where: coupa cafe

let me know,
noam

END_OF_STRING
    assert_equal expected, mail.plaintext_body
    

    mail = TMail::Mail.parse(read_email_file('quoted-printable-2.txt'))
    expected = <<END_OF_STRING
Hi, do you ever outsource flash work/web design/logo design. Please don't hesitate to contact me if you have any work available.  My URL is www.clarewebdesign.co.uk

I would also like to know if you would consider a reciprocal link?

Kindest regards
Hayle Clare

END_OF_STRING
    assert_equal expected, mail.plaintext_body
    

    mail = TMail::Mail.parse(read_email_file('quoted-printable-3.txt'))
    expected = <<END_OF_STRING
Hello Friend,

With due respect and humbleness, I am writing you this letter to
request with my sincere heart for your assistance and hoped that my
request shall meet you in good condition.

My name is Arusi Ikwunnam Mike, i am 21 year's old, my father died of
AIDS Virus last 3 months ago ( may his gentle soul rest in peace )
during his time in hospital, he briefed me in close confidence of his
Money, which is about: US$ 14.million that he left in a foreign
country for safe keeping as the resort of insecurity in our country
due to the civil war, this Money as he told me was made for the
purchase of industrial plant's before he failed ill unfortunately and
was dead.

In the process of securing this Money, i left my country and has now
arrived here in Senegal as my father advised me before his untimely
death to move this Money to any foreign country of my choice where it
will be properly invested as it is not safe investing in our country
due to the civil war.

It is based on this advise that i am contacting you as i am just a
student and does not have any knowledge of investmenting this whole
Money.

Yours Sincerely,
Arusi Ikwunnam Mike.


END_OF_STRING
    assert_equal expected, mail.plaintext_body
    
    
    mail = TMail::Mail.parse(read_email_file('quoted-printable-4.txt'))
    expected = <<END_OF_STRING
so far i'm skeptical that this is better than a  hearty round of gmailing.
time will tell though - I too was once wary of evites and am now a full
convert.

regardless, i do want to go see KML.


On 2/23/06, adam chapman [Skobee] <plans+a54@skobee.com> wrote:
>
> Some peeps are getting together and you're invited!
>
> *What:* killing my lobster
> *When:* Some day this Weekend, Evening
> *Who:*aschapm
> *Where:* 24th Street Cafe, 3853 24th St, San Francisco, CA, 94114 (view a
> map)<http://maps.google.com/maps?q=3853+24th+St%2C+San+Francisco%2C+CA%2C+94114&iwloc=A&hl=en>
>
> *Check out the plan:* here<http://alpha.skobee.com/plans/show/54?user_id=86&ci0=plan54&cn=1&ckey=b832afcfdb675d0c420777c79a9e0fb14a07cf07>
> .
>
> You can set your RSVP status via email. Simply reply to this email and
> include the phrase "*RSVP: I'm In*" or "*RSVP: I'm Out*" on a single line
> in the email body.
>
> You can also suggest a new time, date, or location all without ever
> leaving your email client. Click here to learn how.<http://alpha.skobee.com/email_tour>
>
> ________________________________________________________________________________
> *Make your own plans or check out what your friends are up to. Click here
> to register <http://alpha.skobee.com/users/register/86>*
>
> *If you would like to stop receiving emails from Skobee, please click here<http://alpha.skobee.com/users/disable_all_notifications?user_id=86&ci0=disable_all_notifications&cn=1&ckey=0d00c372bc7c694ebb7365e840bc16fe1c12852d>
> *

END_OF_STRING
    assert_equal expected, mail.plaintext_body
    

    mail = TMail::Mail.parse(read_email_file('quoted-printable-5.txt'))
    expected = <<END_OF_STRING
Thanks for your email. I am now out of the office until Monday 6th March so will get back to you then.

If you have an urgent query please call my mobile 0780 372 1413.

Thanks very much
Sally

http://www.bbc.co.uk/

This e-mail (and any attachments) is confidential and may contain
personal views which are not the views of the BBC unless specifically
stated.
If you have received it in error, please delete it from your system. 
Do not use, copy or disclose the information in any way nor act in
reliance on it and notify the sender immediately. Please note that the
BBC monitors e-mails sent or received. 
Further communication will signify your consent to this.



END_OF_STRING
    assert_equal expected, mail.plaintext_body
  end
  
  def test_bug_985
    #MES- In bug 985, parsing of an email from Exchange overran
    # the end of the email- text in the email that had been replied
    # to was used as a command for the plan.
    User.create_user_from_email_address('kchou@canaan.com', users(:bob))
    plan = Mailman.receive(read_email_file('bug_985.txt'))
    
    #MES- There is no 'when' command, so the plan should start at the
    # default time.
    tz = TZInfo::Timezone.get('America/Tijuana')
    assert_equal Plan::TIME_DESCRIPTION_ALL_DAY, plan.timeperiod
    assert_equal Plan::DATE_DESCRIPTION_FUTURE, plan.dateperiod(tz)
    #MES- There's also no place
    assert_nil plan.place
  end
end
