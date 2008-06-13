module PlannersHelper
  #MGS- character limit to truncate the invitees list
  # before doing the "and 4 more" grouping
  INVITEES_LIST_LARGE_LENGTH = 40
  INVITEES_LIST_SMALL_LENGTH = 27

  def get_user_header(checked_friends)
    #MGS- returns the string of checked clipboard logins at the top of the schedule details page
    logins = []
    checked_friends.each { | friend | logins << friend.login }
    if logins.empty?
      return "What you're up to..."
    elsif logins.length > PlannersController::HEADER_USERNAME_LIMIT
      return "What you and your friends are up to..."
    else
      logins.unshift("you")
      last_user = logins.pop();
      header_string = "#{logins.join(", ")} and #{last_user}"
      return "What #{header_string} are up to..."
    end

  end

  def get_plan_place_name(pln, wrapper = nil, small = false)
    #MGS- build plan/place string; and handle the different null string combos
    #MGS- allow for an optional wrapper to be passed in
    # trying to keep xhtml compliance by not writing out empty tags
    truncate_length =  small ? 25 : 55
    start_tag = wrapper.nil? ? "<span title=\"#{h(pln.name)} #{h(get_place_name(pln, true))}\">" : "<#{wrapper} title=\"#{h(pln.name)} #{h(get_place_name(pln, true))}\">"
    end_tag = wrapper.nil?  ? "</span>" : "</#{wrapper}>"
    #MGS- helper to build the plan name/place row used in the planner pages
    if not_empty_or_nil(pln.name)
      return "#{start_tag}<span class=\"name\">#{truncate(h(pln.name),truncate_length)}</span> #{h(truncate(get_place_name(pln, true), truncate_length))}#{end_tag}"
    elsif !get_place_name(pln).nil?
      return "#{start_tag}#{h(get_place_name(pln, false))}#{end_tag}"
    else
      return nil
    end
  end

  #MGS- helper function to return html for plan place...if it exists
  def get_place_name(pln, at_sign = false)
    if pln.place.nil?
      return nil
    elsif (current_user.nil? || !pln.planners.include?(current_user.planner)) && Place::PLACE_PRIVATE == pln.place.public
      #MGS- fixing bug #765; if the user is not on the plan's invite list
      # and the place is private, don't display place
      return nil
    elsif not_empty_or_nil(pln.place.name)
      return at_sign ? "@ #{pln.place.name}" : pln.place.name
    elsif not_empty_or_nil(pln.place.location)
      return at_sign ? "@ #{pln.place.location}" : pln.place.location
    end
  end

  def get_combined_invitee_list(plan, show_current_user = false, small = false)
    #MGS- gets the invitee list to display
    # - doesn't show the current user in the list
    # - truncates the list after INVITEES_LIST_XXXXX_LENGTH characters
    #   and puts the "and x more" at the end of the list
    #MGS- we're doing a lot of crazy stuff here to make commas black and names blue
		cu = current_user
    max_length = small ? INVITEES_LIST_SMALL_LENGTH : INVITEES_LIST_LARGE_LENGTH
    planners = plan.planners
    invitee_list = []
    invitee_list_length = 0
    count = 0
    planners.each do | cal |
      if cal.owner != cu
        invitee_list << cal.owner.display_name
        invitee_list_length += cal.owner.display_name.length
      elsif show_current_user
        #MGS- if we want to show the current user (ie viewing another user's profile)
        # then add them as the first member of the array
        invitee_list.unshift(cal.owner.display_name)
        invitee_list_length += cal.owner.display_name.length
      end
      #MGS- the current user should add the the count too...
      count+=1
      break if invitee_list_length > max_length
    end

    delimited_invitees = invitee_list.collect!{|invitee| "<span #{"class=\"bold\"" if (!cu.nil? && cu.display_name == invitee)}>#{h(invitee)}</span>"}.join(", ")
    if count == planners.length
      #MGS- the full list was displayed, just chop off the trailing comma
      return  delimited_invitees
    else
      #MGS- we truncated the list, add the "and x more" bit
      return "#{delimited_invitees} and #{(planners.length - count)} more"
    end
  end

  def get_plan_place_invitees(pln, plan_wrapper, invitee_wrapper, show_current_user = false, small = false)
    #MGS- gets the invitee list and plan/place html
    # used so we can send default text back if a plan has no name, invitees
    # or place
    plan_place_name = get_plan_place_name(pln, plan_wrapper, small)
    #MGS- do we want to display a small or large invite list?
    invitee_list = get_combined_invitee_list(pln, show_current_user, small)

    if plan_place_name.nil? && "" == invitee_list
      return "Some plans are brewing..."
    else
      return "#{plan_place_name}<#{invitee_wrapper} class=\"invitees\">#{invitee_list}</#{invitee_wrapper}>"
    end

  end
end
