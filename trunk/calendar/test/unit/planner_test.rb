require File.dirname(__FILE__) + '/../test_helper'

class PlannerTest < Test::Unit::TestCase
  fixtures :planners, :users, :plans, :planners_plans, :user_contacts

  def setup
  end

  # Replace this with your real tests.
  def test_truth
    assert_kind_of Planner,  Planner.find(1)
  end

  def test_user
    #MES- Can we get the owner for a planner?
    cal = Planner.find(1)
    owner = cal.owner
    assert_not_nil owner, 'The user for the planner is nil'

    #MES- Can we set the owner to nil?  We should NOT be able to
    cal.owner = nil
    assert !cal.save, 'A planner with a nil user could be saved'
  end

  def test_name
    #MES- Set the name to a legit value
    cal = Planner.find(1)
    cal.name = 'testing'
    assert cal.save, 'A planner with a legitimate name could not be saved'

    #MES- Blank is legit
    cal.name = ''
    assert cal.save, 'A planner with a blank name could not be saved'

    #MES- Nil is NOT legit
    cal.name = nil
    assert !cal.save, 'A planner with a nil name could be saved'

    #MES- Set the name to a too long value
    cal.name = 'verylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongnameverylongname'
    assert !cal.save, 'A planner with a very long name could be saved'
  end

  def test_visibility_setting
    #MES- The visibility setting may only have certain values, test that it works

    #MES- Legit values
    cal = planners(:existingbob_planner)
    cal.visibility_type = SkobeeConstants::PRIVACY_LEVEL_PUBLIC
    assert cal.save, 'A planner with visibility type PUBLIC could not be saved'
    cal.visibility_type = SkobeeConstants::PRIVACY_LEVEL_FRIENDS
    assert cal.save, 'A planner with visibility type FRIENDS could not be saved'
    cal.visibility_type = SkobeeConstants::PRIVACY_LEVEL_PRIVATE
    assert cal.save, 'A planner with visibility type PRIVATE could not be saved'

    #MES- Illegit values
    cal.visibility_type = -1
    assert !cal.save, 'A planner with visibility type -1 could be saved'
    cal.visibility_type = 500
    assert !cal.save, 'A planner with visibility type 500 could be saved'
    cal.visibility_type = nil
    assert !cal.save, 'A planner with visibility type nil could be saved'

    #MES- When visibility is changed, the cached value for the visibility
    #  (in the planners_plans table) should be updated
    cal = planners(:existingbob_planner, :force)
    assert_equal SkobeeConstants::PRIVACY_LEVEL_PRIVATE, cal.plans[0].planner_visibility_cache.to_i
    cal.visibility_type = SkobeeConstants::PRIVACY_LEVEL_PUBLIC
    cal.save
    cal = planners(:existingbob_planner, :force)
    assert_equal SkobeeConstants::PRIVACY_LEVEL_PUBLIC, cal.plans[0].planner_visibility_cache.to_i

  end

  def test_plans
    #MES- The list of plans should be empty
    cal = planners(:first_planner)
    plns = cal.plans
    assert_equal 0, plns.length, 'An empty planner does not have an empty list of plans'

    #MES- We should be able to add plans, and retrieve them
    pln = plans(:first_plan)
    assert_equal 0, pln.plan_changes.count
    cal.add_plan(pln)
    assert cal.save, 'A planner with a new plan could not be saved'

    cal = planners(:first_planner, :force)
    assert_equal 1, cal.plans.length, 'A planner with one plan does not contain a single plan in the array of plans'

    #MES- The plan should be invited
    pln_from_arr = cal.plans[0]
    assert_equal Plan::STATUS_INVITED, pln_from_arr.cal_pln_status.to_i, 'New plan on planner should have status "invited"'
    #MES- The plan info should cache some info
    assert_equal pln.place_id, pln_from_arr.place_id_cache.to_i, 'Cache of plan place data out of sync with actual plan data'
    assert_equal cal.visibility_type, pln_from_arr.planner_visibility_cache.to_i, 'Cache of plan visibility data out of sync with actual visibility data'
    assert_equal cal.owner.id, pln_from_arr.user_id_cache.to_i, 'Cache of user ID data out of sync with actual visibility data'
    
    #MES- There should be no plan changes
    assert_equal 0, pln.plan_changes.count

    #MES- Accept the plan
    cal.accept_plan(pln)
    #MES- The plan should be accepted in the array of plans
    pln_sought = cal.plans.find(pln.id)
    assert_equal Plan::STATUS_ACCEPTED, pln_sought.cal_pln_status.to_i, 'Accepted plan in cal.plans should have status "accepted"'
    #MES- Check that the data cached into the planner_plans table is correct
    assert_equal pln.place_id, pln_sought.place_id_cache.to_i, 'Cache of plan place data out of sync with actual plan data'
    assert_equal cal.visibility_type, pln_sought.planner_visibility_cache.to_i, 'Cache of plan visibility data out of sync with actual visibility data'
    assert_equal cal.owner.id, pln_from_arr.user_id_cache.to_i, 'Cache of user ID data out of sync with actual visibility data'
    assert_equal Plan::SECURITY_LEVEL_PUBLIC, pln_sought.plan_security_cache.to_i
    #MES- The plan should ALSO be accepted in the DB
    cal = planners(:first_planner, :force)
    pln = cal.plans[0]
    assert_equal Plan::STATUS_ACCEPTED, pln.cal_pln_status.to_i, 'Accepted plan on planner should have status "accepted"'
    
    #MES- There should be a plan change- the accept for the owner of cal
    assert_equal 1, pln.plan_changes.count
    pc = pln.plan_changes.max { |a, b| a.id <=> b.id}
    assert_equal Plan::STATUS_INVITED, pc.initial_rsvp_status
    assert_equal Plan::STATUS_ACCEPTED, pc.final_rsvp_status
    assert_equal cal.owner, pc.owner

    #MES- Reject the plan
    cal.reject_plan(pln)
    #MES- The plan should be rejected in the array of plans
    pln_sought = cal.plans.find(pln.id)
    assert_equal Plan::STATUS_REJECTED, pln_sought.cal_pln_status.to_i, 'Accepted plan in cal.plans should have status "accepted"'
    #MES- The plan should ALSO be rejected in the DB
    cal = planners(:first_planner)
    pln = cal.plans[0]
    assert_equal Plan::STATUS_REJECTED, pln.cal_pln_status.to_i, 'Rejected plan on planner should have status "rejected"'
    
    #MES- There should be a second plan change- the reject
    assert_equal 2, pln.plan_changes.count
    pc = pln.plan_changes.max { |a, b| a.id <=> b.id}
    assert_equal Plan::STATUS_ACCEPTED, pc.initial_rsvp_status
    assert_equal Plan::STATUS_REJECTED, pc.final_rsvp_status
    assert_equal cal.owner, pc.owner

    #MGS- cancel the plan
    cal.cancel_plan(pln)
    #MGS- The plan should be cancelled in the array of plans
    pln_sought = cal.plans.find(pln.id)
    assert_equal Plan::STATUS_CANCELLED, pln_sought.cal_pln_status.to_i, 'Cancelled plan in cal.plans should have status "cancelled"'
    #MGS- The plan should ALSO be cancelled in the DB
    cal = planners(:first_planner)
    pln = cal.plans[0]
    assert_equal Plan::STATUS_CANCELLED, pln.cal_pln_status.to_i, 'Cancelled plan on planner should have status "cancelled"'
    
    #MES- There should be a third plan change- the cancellation
    assert_equal 3, pln.plan_changes.count
    pc = pln.plan_changes.max { |a, b| a.id <=> b.id}
    assert_equal Plan::STATUS_REJECTED, pc.initial_rsvp_status
    assert_equal Plan::STATUS_CANCELLED, pc.final_rsvp_status
    assert_equal cal.owner, pc.owner


    #MES- Remove the plan
    cal.plans.delete(pln)
    assert cal.save, 'A planner with a plan removed could not be saved'
    cal = planners(:first_planner)
    plns = cal.plans
    assert_equal 0, plns.length, 'An empty planner does not have an empty list of plans'

  end

  def test_visibility_level
    #MES- Test that the Planner#visibility_level function returns the correct value

    #MES- Make the "treat_as_administrator" user an administrator
    users(:treat_as_administrator).user_type = User::USER_TYPE_ADMIN

    #MES- Test with a public planner
    cal = users(:user_with_friends).planner
    assert_equal SkobeeConstants::PRIVACY_LEVEL_PUBLIC, cal.visibility_type
    assert_visibility_level cal,  users(:user_with_friends), Planner::USER_VISIBILITY_LEVEL_OWNER
    assert_visibility_level cal,  users(:friend_1_of_user), Planner::USER_VISIBILITY_LEVEL_DETAILS
    assert_visibility_level cal,  users(:not_a_friend), Planner::USER_VISIBILITY_LEVEL_DETAILS
    assert_equal Planner::USER_VISIBILITY_LEVEL_OWNER, cal.visibility_level(users(:treat_as_administrator)), 'Admin does not have OWNER visibility on a public planner'

    #MES- Change the planner to "friends"
    cal.visibility_type = SkobeeConstants::PRIVACY_LEVEL_FRIENDS
    assert cal.save, 'Failed to change visibility of planner to FRIENDS in test_visibility_level'
    cal = users(:user_with_friends).planner
    assert_equal SkobeeConstants::PRIVACY_LEVEL_FRIENDS, cal.visibility_type
    assert_visibility_level cal,  users(:user_with_friends), Planner::USER_VISIBILITY_LEVEL_OWNER
    assert_visibility_level cal,  users(:friend_1_of_user), Planner::USER_VISIBILITY_LEVEL_DETAILS
    assert_visibility_level cal,  users(:not_a_friend), Planner::USER_VISIBILITY_LEVEL_AVAILABILITY
    assert_equal Planner::USER_VISIBILITY_LEVEL_OWNER, cal.visibility_level(users(:treat_as_administrator)), 'Admin does not have OWNER visibility on a friends planner'

    #MES- Change the calender to "private"
    cal.visibility_type = SkobeeConstants::PRIVACY_LEVEL_PRIVATE
    assert cal.save, 'Failed to change visibility of planner to PRIVATE in test_visibility_level'
    cal = users(:user_with_friends).planner
    assert_equal SkobeeConstants::PRIVACY_LEVEL_PRIVATE, cal.visibility_type
    assert_visibility_level cal,  users(:user_with_friends), Planner::USER_VISIBILITY_LEVEL_OWNER
    assert_visibility_level cal,  users(:friend_1_of_user), Planner::USER_VISIBILITY_LEVEL_AVAILABILITY
    assert_visibility_level cal,  users(:not_a_friend), Planner::USER_VISIBILITY_LEVEL_AVAILABILITY
    assert_equal Planner::USER_VISIBILITY_LEVEL_OWNER, cal.visibility_level(users(:treat_as_administrator)), 'Admin does not have OWNER visibility on a private planner'

  end

  #MES- A helper function for test_visibility_level
  def assert_visibility_level(cal, user, level)
    assert_equal level, cal.visibility_level(user), "Planner #{cal.id} has wrong visibility level for user #{user.id} when passing in user object"
    assert_equal level, cal.visibility_level(user.id), "Planner #{cal.id} has wrong visibility level for user #{user.id} when passing in user ID as numeric"
  end
  
  def test_visible_plans
    #MES- Visible plans returns the elements in Planner#plans that are visible to the specified user
    plnr = planners(:existingbob_planner)
    assert_equal 5, plnr.plans.length
    ebob = users(:existingbob)
    assert_equal 5, plnr.visible_plans(ebob.id).length
    bob = users(:bob)
    assert_equal 5, plnr.visible_plans(bob.id).length
    #MES- Make a plan private
    pln = plans(:first_plan)
    pln.security_level = Plan::SECURITY_LEVEL_PRIVATE
    pln.save!
    plnr = planners(:existingbob_planner, :force)
    #MES- The owner should still see it
    assert_equal 5, plnr.visible_plans(ebob.id).length
    #MES- But bob should not
    assert_equal 4, plnr.visible_plans(bob.id).length
  end
  
  def test_plan_display
    #MES- Kinda strange place for these tests, but gotta put it somewhere
    usr = users(:existingbob)
    new, fuzzy, solid = PlanDisplay.collect_plan_infos(usr, usr.planner)
    #MES- Since we did NOT set the "do not group" argument, there will be 
    #  three groups returned- new plans, fuzzy plans, and solid plans
    assert_equal 0, new.length
    assert_equal 3, fuzzy.length
    assert_equal 1, solid.length
    
    pln = plans(:first_plan)
    assert fuzzy.detect { |pd| pd.plan.id == pln.id }
    pln = plans(:plan_for_bob_place)
    assert fuzzy.detect { |pd| pd.plan.id == pln.id }
    pln = plans(:plan_for_existingbob)
    assert fuzzy.detect { |pd| pd.plan.id == pln.id }
    
    pln = plans(:solid_plan_in_expiry_window)
    assert solid.detect { |pd| pd.plan.id == pln.id }
    
    #MES- If we do not group, it should be the same info, but in a big list
    pds = PlanDisplay.collect_plan_infos(usr, usr.planner, nil, false)
    assert_equal 4, pds.length
    pln = plans(:first_plan)
    assert pds.detect { |pd| pd.plan.id == pln.id }
    pln = plans(:plan_for_bob_place)
    assert pds.detect { |pd| pd.plan.id == pln.id }
    pln = plans(:plan_for_existingbob)
    assert pds.detect { |pd| pd.plan.id == pln.id }
    pln = plans(:solid_plan_in_expiry_window)
    assert pds.detect { |pd| pd.plan.id == pln.id }
    
    #MES- If we include contacts, the contact info should show up
    bob = users(:bob)
    pds = PlanDisplay.collect_plan_infos(bob, bob.planner, [usr], false)
    assert_equal 4, pds.length
    pln = plans(:first_plan)
    assert pds.detect { |pd| pd.plan.id == pln.id }
    pln = plans(:plan_for_bob_place)
    assert pds.detect { |pd| pd.plan.id == pln.id }
    pln = plans(:plan_for_existingbob)
    assert pds.detect { |pd| pd.plan.id == pln.id }
    pln = plans(:solid_plan_in_expiry_window)
    assert pds.detect { |pd| pd.plan.id == pln.id }
    
    #MES- If a plan is private, it should NOT show up from a contact
    pln = plans(:plan_for_existingbob)
    pln.security_level = Plan::SECURITY_LEVEL_PRIVATE
    pln.save!
    bob = users(:bob, :force)
    usr = users(:existingbob, :force)
    pds = PlanDisplay.collect_plan_infos(bob, bob.planner, [usr], false)
    assert_equal 3, pds.length

    #MES- But the owner should be able to see it
    pds = PlanDisplay.collect_plan_infos(usr, usr.planner, nil, false)
    assert_equal 4, pds.length
  end
  
  def test_find_p_and_u_by_id_or_login
    plnr = planners(:first_planner)
  	p, u = Planner.find_p_and_u_by_id_or_login(plnr.id.to_s)
  	assert_equal plnr, p
  	assert_equal plnr.owner, u
  	
  	assert_raise(ActiveRecord::RecordNotFound) { Planner.find_p_and_u_by_id_or_login('0') }
  		
  	p, u = Planner.find_p_and_u_by_id_or_login(plnr.owner.login)
  	assert_equal plnr, p
  	assert_equal plnr.owner, u
  end
end
