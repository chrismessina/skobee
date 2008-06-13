class PlanDisplay
  attr_accessor  :plan
  attr_accessor  :tentative
  attr_reader :attendees
  attr_reader :visibility
  attr_reader :owning_planner
  attr_reader :num_unviewed_items

  def initialize (plan, visibility, owner, owning_planner, tentative, num_unviewed_items = 0)
    self.plan = plan
    @visibility = visibility
    @attendees = [owner]
    @owning_planner = owning_planner
    self.tentative = tentative
    @num_unviewed_items = num_unviewed_items
  end

  def add_attendee(new_attendee)
    @attendees << new_attendee
  end

  def update_visibility(vis, cal)
    #MGS- always want to have the highest visibility possible
    # only set the visibility if it's higher than the current set value
    if @visibility.nil? || vis > @visibility
      @visibility = vis
      @owning_planner = cal
    end
  end

  def <=>(other)
    return self.plan <=> other.plan
  end

  #MGS- class method that handles the gathering of plan display objects
  # used in the planners and in some of the feeds
  def self.collect_plan_infos(viewing_user, user_cal, contacts = nil, group = true)
    new_plan_displays = {}
    fuzzy_plan_displays = {}
    solid_plan_displays = {}
		if !viewing_user.nil?
			time_filter_user = viewing_user
		else
			time_filter_user = user_cal.owner
		end
    user_cal.set_plans_time_filter(time_filter_user)
    viewing_user_id = viewing_user.nil? ? nil : viewing_user.id
    user_plans = user_cal.visible_plans(viewing_user_id)
    #MGS- get the timezone from the viewing user, or from the calendar owner
		tz = time_filter_user.tz
    
    plan_ids_with_unviewed = user_cal.plan_ids_with_unviewed
    
    user_plans.each do | pln |
      num_unviewed_items = 0
      num_unviewed_items = plan_ids_with_unviewed[pln.id] if plan_ids_with_unviewed.has_key?(pln.id)
      #MES- We don't want to show rejected plans
      if Plan::STATUSES_ACCEPTED.member?(pln.cal_pln_status.to_i)
        if pln.fuzzy?(tz)
          fuzzy_plan_displays[pln.id] = PlanDisplay.new(pln, Planner::USER_VISIBILITY_LEVEL_OWNER, user_cal.owner, user_cal.id, true, num_unviewed_items)
        else
          #MGS- solid plan
          solid_plan_displays[pln.id] = PlanDisplay.new(pln, Planner::USER_VISIBILITY_LEVEL_OWNER, user_cal.owner, user_cal.id, true, num_unviewed_items)
        end
      elsif Plan::STATUS_INVITED == pln.cal_pln_status.to_i
        new_plan_displays[pln.id] = PlanDisplay.new(pln, Planner::USER_VISIBILITY_LEVEL_OWNER, user_cal.owner, user_cal.id, true, num_unviewed_items)
      end
    end

    #MGS- this is a special case, currently only used by the planner show pages where we don't want plan grouping;
    # don't want new plans and no fuzzy/solid groupings
    # It's a little weird that one method can have either one retval or three...but it's ruby...why not?
    #MGS- we also don't need to loop through your contacts as plans aren't interleaved
    # for the planner show page
    if contacts.nil? && false == group
      combined_plan_displays = fuzzy_plan_displays.values + solid_plan_displays.values
      return combined_plan_displays.sort!
    end

    #MGS- delete the rejected plans from the user plans array
    # these plans will then be allowed to show up from your friends
    # planners; see Ticket #273
    user_plans.delete_if {| pln | Plan::STATUSES_REJECTED.member?(pln.cal_pln_status.to_i)}

    if !contacts.nil?
      contacts.each do | contact |
        cal = contact.planner
        vis = cal.visibility_level(viewing_user)
        cal.set_plans_time_filter(time_filter_user)
        cal.visible_plans(viewing_user_id).each do | pln |
          #MES- We only want to show confirmed plans, and we
          #  only want to show plans that aren't ALREADY being
          #  shown in all_plan_displays
          if Plan::STATUSES_ACCEPTED.member?(pln.cal_pln_status.to_i) && !user_plans.include?(pln)
            if pln.fuzzy?(tz)
              if fuzzy_plan_displays.has_key?(pln.id)
                #MGS- handle the case where the plan already exists in the hash
                plan_info = fuzzy_plan_displays[pln.id]
                plan_info.add_attendee(contact)
                plan_info.update_visibility(vis, cal.id)
              else
                #MGS- this plan doesn't exist in the hash...add it
                fuzzy_plan_displays[pln.id] = PlanDisplay.new(pln, vis, contact, cal.id, false)
              end
            else
              if solid_plan_displays.has_key?(pln.id)
                #MGS- handle the case where the plan already exists in the hash
                plan_info = solid_plan_displays[pln.id]
                plan_info.add_attendee(contact)
                plan_info.update_visibility(vis, cal.id)
              else
                #MGS- this plan doesn't exist in the hash...add it
                solid_plan_displays[pln.id] = PlanDisplay.new(pln, vis, contact, cal.id, false)
              end
            end
          end
        end
      end
    end


    #MGS- check if we want the combined plans or separate plan collections
    # for schedule details, we want plans grouped by fuzzy/solid, but for
    # the feeds, we want them all in one list.
    if group
      #MGS- Sort using plan#<=>
      new = new_plan_displays.values.sort
      fuzzy = fuzzy_plan_displays.values.sort
      solid = solid_plan_displays.values.sort
      return new, fuzzy, solid
    else
      #MGS- this is currently only used in the feeds where we want to have fuzzy and solid feeds interleaved
      combined_plan_displays = fuzzy_plan_displays.values + solid_plan_displays.values
      return combined_plan_displays.sort!
    end

  end
end
