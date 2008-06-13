require File.dirname(__FILE__) + '/../test_helper'

class PlanChangeTest < Test::Unit::TestCase
  fixtures :users, :plan_changes, :places, :plans

  def test_place_changed
    chg = PlanChange.new()
    chg.place_changed(users(:bob), places(:first_place), places(:another_place))
    chg.comment = 'comment!'
    chg.save
    chg = PlanChange.find(chg.id)
    assert_equal PlanChange::CHANGE_TYPE_PLACE, chg.change_type
    assert_equal places(:first_place), chg.initial_place
    assert_equal places(:another_place), chg.final_place
    assert_equal 'comment!', chg.comment
    assert_equal users(:bob), chg.owner
  end

  def test_time_changed
    chg = PlanChange.new()
    old_start = Time.now() - 10
    old_timeperiod = Plan::TIME_DESCRIPTION_DINNER
    old_fuzzy_start = Time.now() - 5
    old_duration = 123
    new_start = Time.now() + 10
    new_timeperiod = Plan::TIME_DESCRIPTION_BREAKFAST
    new_fuzzy_start = Time.now() + 5
    new_duration = 234
    chg.time_changed(users(:bob), old_start, old_timeperiod, old_fuzzy_start, old_duration, new_start, new_timeperiod, new_fuzzy_start, new_duration)
    chg.comment = 'comment!'
    chg.save
    chg = PlanChange.find(chg.id)
    assert_equal PlanChange::CHANGE_TYPE_TIME, chg.change_type
    assert_equal old_start.to_i, chg.initial_time[PlanChange::TIME_CHANGE_START_INDEX].to_i
    assert_equal old_timeperiod, chg.initial_time[PlanChange::TIME_CHANGE_TIMEPERIOD_INDEX]
    assert_equal old_fuzzy_start.to_i, chg.initial_time[PlanChange::TIME_CHANGE_FUZZY_START_INDEX].to_i
    assert_equal old_duration,  chg.initial_time[PlanChange::TIME_CHANGE_DURATION_INDEX]
    assert_equal new_start.to_i, chg.final_time[PlanChange::TIME_CHANGE_START_INDEX].to_i
    assert_equal new_timeperiod, chg.final_time[PlanChange::TIME_CHANGE_TIMEPERIOD_INDEX]
    assert_equal new_fuzzy_start.to_i, chg.final_time[PlanChange::TIME_CHANGE_FUZZY_START_INDEX].to_i
    assert_equal new_duration,  chg.final_time[PlanChange::TIME_CHANGE_DURATION_INDEX]
    assert_equal 'comment!', chg.comment
    assert_equal users(:bob), chg.owner
  end

  def test_comment
    chg = PlanChange.new()
    chg.comment = 'comment!'
    chg.owner = users(:bob)
    chg.save
    chg = PlanChange.find(chg.id)
    assert_equal PlanChange::CHANGE_TYPE_COMMENT, chg.change_type
    assert_equal 'comment!', chg.comment
    assert_equal users(:bob), chg.owner
  end

  def test_rsvp
    chg = PlanChange.new()
    chg.comment = 'RSVP changes can have a comment too'
    chg.rsvp_changed(users(:bob), Plan::STATUS_ACCEPTED, Plan::STATUS_REJECTED)
    chg.save
    chg = PlanChange.find(chg.id)
    assert_equal PlanChange::CHANGE_TYPE_RSVP, chg.change_type
    assert_equal Plan::STATUS_ACCEPTED, chg.initial_rsvp_status
    assert_equal Plan::STATUS_REJECTED, chg.final_rsvp_status
    assert_equal 'RSVP changes can have a comment too', chg.comment
    assert_equal users(:bob), chg.owner
  end

  def test_delete_from_collection
    chg = PlanChange.new()
    chg.comment = 'comment!'
    chg.owner = users(:bob)
    chg.save
    chg_id = chg.id

    #MES- Try with the "correct" security
    coll = [chg]
    chg.delete_from_collection(users(:bob), coll)
    #MES- The collection should be empty
    assert coll.empty?
    #MES- And the change should be deleted
    assert !PlanChange.exists?(chg_id)


    #MES- Try with the "wrong" security
    chg = PlanChange.new()
    chg.comment = 'comment!'
    chg.owner = users(:bob)
    chg_id = chg.id
    chg.save
    chg_id = chg.id

    coll = [chg]
    assert_raise(RuntimeError) { chg.delete_from_collection(users(:longbob), coll) }

    assert !coll.empty?
    assert PlanChange.exists?(chg_id)
  end

#MES- THE find_altered FUNCTION IS DEFUNCT!
#  def test_find_altered
#    #MES- There's only one altered plan in the test data
#    res = PlanChange.find_altered(users(:contact_1_of_user))
#    assert_equal 1, res.length
#
#    #MES- Users who aren't on the plan shouldn't see it
#    res = PlanChange.find_altered(users(:bob))
#    assert_equal 0, res.length
#
#    #MES- user_with_friends has accepted some plans, but they haven't
#    # been altered
#    res = PlanChange.find_altered(users(:user_with_friends))
#    assert_equal 0, res.length
#
#    #MES- But if we alter the plan, they should see it.
#    plan = plans(:future_plan_1)
#    plan.checkpoint_for_revert(users(:friend_1_of_user))
#    plan.place = places(:another_place)
#    plan.save
#
#    res = PlanChange.find_altered(users(:user_with_friends))
#    assert_equal 1, res.length
#    assert_equal plan.plan_changes[0], res[0]
#
#    #MES- While we're here, test that the plan for the change is the right plan
#    assert_equal plan, plan.plan_changes[0].plan
#  end

  def test_find_recent
    #MES- Look for a change
    res = PlanChange.find_recent(users(:contact_1_of_user), false)
    assert_equal 5, res.length
    #MGS- test excluding the user
    res = PlanChange.find_recent(users(:contact_1_of_user))
    assert_equal 5, res.length

    #MES- Users who aren't on the plan shouldn't see it
    res = PlanChange.find_recent(users(:bob), false)
    assert_equal 0, res.length
    #MGS- test excluding the user
    res = PlanChange.find_recent(users(:bob))
    assert_equal 0, res.length

    #MES- user_with_friends has accepted some plans, but they haven't
    # been altered
    res = PlanChange.find_recent(users(:user_with_friends), false)
    assert_equal 0, res.length
    #MGS- test excluding the user
    res = PlanChange.find_recent(users(:user_with_friends))
    assert_equal 0, res.length

    #MES- But if we alter the plan, they should see it.
    plan = plans(:future_plan_1)
    plan.checkpoint_for_revert(users(:friend_1_of_user))
    plan.place = places(:another_place)
    plan.save

    res = PlanChange.find_recent(users(:user_with_friends), false)
    #MES- NOTE: The first change creates two PlanChange objects (one for the
    # original value, and one for the changed value.)
    assert_equal 2, res.length
    assert plan.plan_changes.include?(res[0])
    assert plan.plan_changes.include?(res[1])
    #MGS- test excluding the user
    res = PlanChange.find_recent(users(:user_with_friends))
    assert_equal 1, res.length
    assert plan.plan_changes.include?(res[0])

    #MES- While we're here, test that the plan for the change is the right plan
    assert_equal plan, plan.plan_changes[0].plan

    #MES- They should see it even if they've made the change
    plan = plans(:future_plan_1)
    plan.checkpoint_for_revert(users(:user_with_friends))
    plan.place = places(:first_place)
    plan.save

    res = PlanChange.find_recent(users(:user_with_friends), false)
    assert_equal 3, res.length
    assert plan.plan_changes.include?(res[0])
    assert_equal places(:first_place), res[0].final_place
    #MGS- test excluding the user
    res = PlanChange.find_recent(users(:user_with_friends))
    assert_equal 1, res.length
    assert plan.plan_changes.include?(res[0])
  end

  def test_find_recent_for_user
    #MGS- look for changes passing in a user object
    res = PlanChange.find_recent_for_user(users(:user_with_contacts))
    assert_equal 6, res.length
    #MGS- A ruby way to check that all of the owner_ids are the same on the plan changes
    assert_equal 1, res.collect!{ |r| r.owner_id }.uniq!.length
    assert_equal users(:user_with_contacts).id, res[0]

    #MGS- look for changes passing in user ids
    res = PlanChange.find_recent_for_user(users(:user_with_contacts).id)
    assert_equal 6, res.length
    #MGS- A ruby way to check that all of the owner_ids are the same on the plan changes
    assert_equal 1, res.collect!{ |r| r.owner_id }.uniq!.length
    assert_equal users(:user_with_contacts).id, res[0]

    #MGS- make a plan change as a different user
    plan = plans(:second_plan_for_place_stats)
    plan.checkpoint_for_revert(users(:friend_1_of_user))
    plan.set_datetime(TZInfo::Timezone.get('America/Tijuana'), Plan::DATE_DESCRIPTION_NEXT_WEEKEND, Plan::TIME_DESCRIPTION_BREAKFAST)
    plan.save

    #MGS- this new plan change shouldn't appear when just querying for user_with_contacts
    res = PlanChange.find_recent_for_user(users(:user_with_contacts).id)
    assert_equal 6, res.length
    #MGS- A ruby way to check that all of the owner_ids are the same on the plan changes
    assert_equal 1, res.collect!{ |r| r.owner_id }.uniq!.length
    assert_equal users(:user_with_contacts).id, res[0]
    
    #MES- If one of the plans is private, it shouldn't show up.
    # Since all the changes are for the same plan, they'll all disappear.
    pln = plans(:second_plan_for_place_stats)
    pln.security_level = Plan::SECURITY_LEVEL_PRIVATE
    pln.save!
    res = PlanChange.find_recent_for_user(users(:user_with_contacts).id)
    assert_equal 0, res.length    
  end

  def test_find_contact_recent_changes_for_friends_and_contacts
    #MGS- this tests PlanChange.find_contact_recent_changes, searching for friends and contacts
    contact_1_of_user = users(:contact_1_of_user)
    user_with_contacts = users(:user_with_contacts)
    res = PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_CONTACT, User::FRIEND_STATUS_FRIEND])

    #MGS- assert that user_with_contacts is a FRIEND of contact_1_of_user
    assert contact_1_of_user.friends.include?(user_with_contacts)
    #MGS- assert that user_with_contacts has a public planner for good measure
    assert_equal SkobeeConstants::PRIVACY_LEVEL_PUBLIC, user_with_contacts.planner.visibility_type
    #MGS- user_with_contacts is a friend of contact_1_of_user and has made a lot of changes.
    # Since this query pulls in friends + contacts and user_with_contacts has a public
    # planner...we see these changes
    assert_equal 6, res.length
    assert_equal plan_changes(:time_comment_for_existing_bob), res[0]
    assert_equal plan_changes(:noaml_anniversary), res[1]
    assert_equal plan_changes(:time_change_to_test_plans_a_changin), res[2]
    assert_equal plan_changes(:place_change_to_test_plans_a_changin), res[3]
    assert_equal plan_changes(:change_to_test_plans_a_changin), res[4]
    assert_equal plan_changes(:change_for_second_plan_for_place_stats), res[5]

    #MGS- set user_with_contacts as a contact instead of a friend
    contact_1_of_user.add_or_update_contact(user_with_contacts, { :friend_status => User::FRIEND_STATUS_CONTACT })
    res = PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_CONTACT, User::FRIEND_STATUS_FRIEND])

    #MGS- user_with_contacts is a contact of contact_1_of_user and has made a lot of changes.
    # Since this query pulls in friends + contacts and user_with_contacts has a public
    # planner...we see these changes
    assert_equal 6, res.length
    assert_equal plan_changes(:time_comment_for_existing_bob), res[0]
    assert_equal plan_changes(:noaml_anniversary), res[1]
    assert_equal plan_changes(:time_change_to_test_plans_a_changin), res[2]
    assert_equal plan_changes(:place_change_to_test_plans_a_changin), res[3]
    assert_equal plan_changes(:change_to_test_plans_a_changin), res[4]
    assert_equal plan_changes(:change_for_second_plan_for_place_stats), res[5]

    #MGS- set user_with_contacts as a no relationship
    contact_1_of_user.add_or_update_contact(user_with_contacts, { :friend_status => User::FRIEND_STATUS_NONE})
    res = PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_CONTACT, User::FRIEND_STATUS_FRIEND])

    #MGS- user_with_contacts is a nothing to contact_1_of_user and has made a lot of changes.
    # We should see no changes
    assert_equal 0, res.length

    #MGS- now set user_with_contacts back to a FRIEND
    contact_1_of_user.add_or_update_contact(user_with_contacts, { :friend_status => User::FRIEND_STATUS_FRIEND})
    #MGS- and change the visibilty level of user_with_contacts planner to PRIVACY_LEVEL_FRIENDS
    cal = user_with_contacts.planner
    cal.visibility_type = SkobeeConstants::PRIVACY_LEVEL_FRIENDS
    assert cal.save
    #MGS- since user_with_contacts has not set contact_1_of_user as a friend, contact_1_of_user
    # should see no plan changes
    res = PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_CONTACT, User::FRIEND_STATUS_FRIEND])
    assert_equal 0, res.length

    #MGS- now set contact_1_of_user as a friend of user_with_contacts
    user_with_contacts.add_or_update_contact(contact_1_of_user, { :friend_status => User::FRIEND_STATUS_FRIEND})
    res = PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_CONTACT, User::FRIEND_STATUS_FRIEND])
    assert_equal 6, res.length
    assert_equal plan_changes(:time_comment_for_existing_bob), res[0]
    assert_equal plan_changes(:noaml_anniversary), res[1]
    assert_equal plan_changes(:time_change_to_test_plans_a_changin), res[2]
    assert_equal plan_changes(:place_change_to_test_plans_a_changin), res[3]
    assert_equal plan_changes(:change_to_test_plans_a_changin), res[4]
    assert_equal plan_changes(:change_for_second_plan_for_place_stats), res[5]

    #MGS- now change the user_with_contacts visibility level to private and user_with_contacts
    # should still see nothing
    cal = user_with_contacts.planner
    cal.visibility_type = SkobeeConstants::PRIVACY_LEVEL_PRIVATE
    assert cal.save
    res = PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_CONTACT, User::FRIEND_STATUS_FRIEND])
    assert_equal 0, res.length
    
    #MES- When the PLAN is private, changes on it shouldn't be visible
    cal.visibility_type = SkobeeConstants::PRIVACY_LEVEL_PUBLIC
    cal.save!
    assert_equal 6, PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_CONTACT, User::FRIEND_STATUS_FRIEND]).length
    #MES Since all the changes are for the same plan, they'll all disappear.
    pln = plans(:second_plan_for_place_stats)
    pln.security_level = Plan::SECURITY_LEVEL_PRIVATE
    pln.save!
    assert_equal 0, PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_CONTACT, User::FRIEND_STATUS_FRIEND]).length
    
  end

  def test_find_contact_recent_changes_for_friends
    #MGS- this tests PlanChange.find_contact_recent_changes, searching for just friends
    contact_1_of_user = users(:contact_1_of_user)
    user_with_contacts = users(:user_with_contacts)

    #MGS- double check the fixtures to start the test
    #MGS- assert that user_with_contacts is a friend of contact_1_of_user
    assert contact_1_of_user.friends.include?(user_with_contacts)
    #MGS- assert that user_with_contacts has not set contact_1_of_user as a friend or a contact
    assert !user_with_contacts.friends_and_contacts.include?(contact_1_of_user)
    #MGS- assert that user_with_contacts's planner is public
    assert_equal SkobeeConstants::PRIVACY_LEVEL_PUBLIC, user_with_contacts.planner.visibility_type

    res = PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_FRIEND])
    #MGS- user_with_contacts is a friend of contact_1_of_user and has made a lot of changes.
    assert_equal 6, res.length
    assert_equal plan_changes(:time_comment_for_existing_bob), res[0]
    assert_equal plan_changes(:noaml_anniversary), res[1]
    assert_equal plan_changes(:time_change_to_test_plans_a_changin), res[2]
    assert_equal plan_changes(:place_change_to_test_plans_a_changin), res[3]
    assert_equal plan_changes(:change_to_test_plans_a_changin), res[4]
    assert_equal plan_changes(:change_for_second_plan_for_place_stats), res[5]

    #MGS- set user_with_contacts as a contact
    contact_1_of_user.add_or_update_contact(user_with_contacts, { :friend_status => User::FRIEND_STATUS_CONTACT})
    #MGS- no results should be returned
    assert_equal 0, PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_FRIEND]).length
    #MGS- set user_with_contacts as no relationship
    contact_1_of_user.add_or_update_contact(user_with_contacts, { :friend_status => User::FRIEND_STATUS_NONE})
    #MGS- no results should be returned
    assert_equal 0, PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_FRIEND]).length

    #MGS- now set user_with_contacts back as a friend
    contact_1_of_user.add_or_update_contact(user_with_contacts, { :friend_status => User::FRIEND_STATUS_FRIEND})
    #MGS- and set the visibility level of their planner to PRIVATE
    cal = user_with_contacts.planner
    cal.visibility_type = SkobeeConstants::PRIVACY_LEVEL_PRIVATE
    assert cal.save
    #MGS- no results should be returned
    assert_equal 0, PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_FRIEND]).length

    #MGS- now set the visibility level of their planner to FRIENDS_ONLY
    cal = user_with_contacts.planner
    cal.visibility_type = SkobeeConstants::PRIVACY_LEVEL_FRIENDS
    assert cal.save
    #MGS- no results should be returned as user_with_contacts has not added contact_1_of_user as a friend
    assert_equal 0, PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_FRIEND]).length

    #MGS- now add contact_1_of_user as a contact
    user_with_contacts.add_or_update_contact(contact_1_of_user, { :friend_status => User::FRIEND_STATUS_CONTACT})
    #MGS- no results should be returned as being a contact doesn't help with FRIENDS_ONLY security
    assert_equal 0, PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_FRIEND]).length

    #MGS- now add contact_1_of_user as a friend
    user_with_contacts.add_or_update_contact(contact_1_of_user, { :friend_status => User::FRIEND_STATUS_FRIEND})
    #MGS- the security checks out, and 6 plan changes should be returned
    assert_equal 6, PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_FRIEND]).length
    assert_equal plan_changes(:time_comment_for_existing_bob), res[0]
    assert_equal plan_changes(:noaml_anniversary), res[1]
    assert_equal plan_changes(:time_change_to_test_plans_a_changin), res[2]
    assert_equal plan_changes(:place_change_to_test_plans_a_changin), res[3]
    assert_equal plan_changes(:change_to_test_plans_a_changin), res[4]
    assert_equal plan_changes(:change_for_second_plan_for_place_stats), res[5]

    #MGS- now for extra credit, make a plan change as someone else with no relationship, to make sure its not returned
    plan = plans(:second_plan_for_place_stats)
    plan.checkpoint_for_revert(users(:friend_1_of_user))
    plan.set_datetime(TZInfo::Timezone.get('America/Tijuana'), Plan::DATE_DESCRIPTION_NEXT_WEEKEND, Plan::TIME_DESCRIPTION_BREAKFAST)
    plan.save

    #MGS- the security checks out, and 6 plan changes should be returned
    assert_equal 6, PlanChange.find_contact_recent_changes(contact_1_of_user, [User::FRIEND_STATUS_FRIEND]).length
    assert_equal plan_changes(:time_comment_for_existing_bob), res[0]
    assert_equal plan_changes(:noaml_anniversary), res[1]
    assert_equal plan_changes(:time_change_to_test_plans_a_changin), res[2]
    assert_equal plan_changes(:place_change_to_test_plans_a_changin), res[3]
    assert_equal plan_changes(:change_to_test_plans_a_changin), res[4]
    assert_equal plan_changes(:change_for_second_plan_for_place_stats), res[5]
  end

end