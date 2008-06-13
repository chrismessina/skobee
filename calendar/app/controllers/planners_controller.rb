class PlannersController < ApplicationController
  require 'erb'
  include PlannersHelper
  include ERB::Util

  #MGS- including plans helper because common plan display functions are located there
  helper :plans
  before_filter :login_required, :set_static_includes, :conditional_login_required

  SCHEDULE_DETAILS_PLAN_TEMPLATES = {
    Planner::USER_VISIBILITY_LEVEL_AVAILABILITY => 'schedule_details_plan_availability',
    Planner::USER_VISIBILITY_LEVEL_DETAILS => 'schedule_details_plan_details',
    Planner::USER_VISIBILITY_LEVEL_OWNER => 'schedule_details_plan_owner',
  }

  SHOW_PLAN_TEMPLATES = {
    Planner::USER_VISIBILITY_LEVEL_AVAILABILITY => 'show_plan_availability',
    Planner::USER_VISIBILITY_LEVEL_DETAILS => 'show_plan_details',
    Planner::USER_VISIBILITY_LEVEL_OWNER => 'show_plan_owner',
  }

  DASHBOARD_PLAN_TEMPLATES = {
    Planner::USER_VISIBILITY_LEVEL_AVAILABILITY => 'dashboard_plan_availability',
    Planner::USER_VISIBILITY_LEVEL_DETAILS => 'dashboard_plan_details',
    Planner::USER_VISIBILITY_LEVEL_OWNER => 'dashboard_plan_owner',
  }

  #MGS- cap the clipboard limit to 15 for now
  CONTACT_CLIPBOARD_LIMIT = 15
  #MGS- the limit of usernames to display in the schedule details header
  HEADER_USERNAME_LIMIT = 2

  PROFILE_MAX_PLANS = 4
  PROFILE_MAX_CONTACTS = 10
  PROFILE_MAX_COMMENTS = 5
  
  CHANGE_STATUS_ACTIONS = ['accept_plan', 'express_interest_in_plan', 'reject_plan']
  #MES- show doesn't require login or conditional login
  ACTIONS_REQUIRING_LOGIN = CHANGE_STATUS_ACTIONS + ['show']

  def store_loc_before_authenticate?(action_name)
    #MES- If the user got to an AJAX action, but isn't logged in, we do NOT
    # want to store their location- we do NOT want to redirect back to the
    # AJAX action.
    return false if ['edit_clipboard_status_ajax', 'remove_contact_from_clipboard_ajax', 'add_contact_to_clipboard_ajax'].include?(action_name)

    return true
  end
  
  def login_required_for?(action)
  	#MES- Exclude the actions that respond to conditional logins
    return false if ACTIONS_REQUIRING_LOGIN.include?(action)
    return true
  end
  
  def conditional_login_required_for?(action)
    #MES- Changing status requires conditional login
    return true if CHANGE_STATUS_ACTIONS.include?(action)
    return false
  end

  def conditional_login_requirement_met?(action_name, current_user_conditions)
  	#MES- For actions related to plan status, the user conditions must refer to the relevant plan
  	if CHANGE_STATUS_ACTIONS.include?(action_name)
  		#MES- Check that they're trying to accept the plan that is in the URL
	    plan_id = params[:pln_id]
	    expected_item = UserNotify.conditional_item_for_plan(plan_id)
	
	    return true if current_user_conditions.include?(expected_item)
  	end
  	
  	#MES- Don't know what this is
  	return false
  end

  def show
    #MES- Note: there's no explicit security check here, since
    #  every user can see the planner for every other user (at
    #  least the availability.)

    #MES- If we were handed a user ID instead of a planner ID, translate it
    if params.include?(:user_id) && !params.include?(:id)
      @user = User.find(params[:user_id])
      @planner = @user.planner
    elsif params.include?(:id)
    	#MES- The ID might be the id of a planner, or the login of a user
    	@planner, @user = Planner.find_p_and_u_by_id_or_login(params[:id])
    else
      @user = current_user
      if @user.nil?
      	#MES- Error- they didn't pass in a planner id, and they're not logged in.
      	#	Let's just redirect to login
      	redirect_to :controller => 'users', :action => 'login'
      	return
      end
      @planner = @user.planner
    end

    #MGS- get the combined collection of friends and contacts
    # and sort the users to bring those who have avatars to the
    # top of the list.
    @combined_contacts = @user.friends_and_contacts.sort{ |a, b|
      (a.image.nil? ? 1:0) <=> (b.image.nil? ? 1:0)
    }

    store_location

    #KS- get the user's random places
    @random_places = Place.find_user_random_places(@user.id)

    #MES- Show the plan using the correct template.  Note that
    # we are using the same template for ALL plans, since all of the
    # plans are on the same planner, and therefore have the same
    # visibility (different from the schedule_details view.)
    vis_level = @planner.visibility_level(current_user)
    @plan_template = SHOW_PLAN_TEMPLATES[vis_level]
    
    @viewing_timezone = current_user.nil? ? @user.tz : current_user.tz

    #MGS- don't show plans if all user can see is the availability view
    if Planner::USER_VISIBILITY_LEVEL_AVAILABILITY == vis_level
      @plan_infos = []
      return
    else
      #MGS- if the viewing user has more than just availibility access, show an rss link on the page
      @rss_feeds = { "Skobee: #{h(Inflector.possessiveize(@user.login))} plans" => url_for(:controller => 'feeds', :action => 'user', :id => current_user_id, :planner_id => @planner.id, :only_path => false) }
    end

    #MGS- Collect all of the plans from all of the planners we're interested in
    @plan_infos = PlanDisplay.collect_plan_infos(current_user, @planner, nil, false)
  end

  def schedule_details
    #MES- If no ID was passed in we'll just use the planner for the current user, so
    #  we don't need to check security
    if params.include? :id
      begin
        check_security(params[:id])
      rescue
        #MES- The current user doesn't have rights to see the details for the planner,
        #  redirect them to the standard view
        redirect_to :action => 'show', :id => params[:id]
      end
    end

    @user = current_user
    store_location
    @selected_clipboard_contacts = @user.selected_clipboard_contacts
    #MGS- get the user header AKA "what you, michaels, and noaml are up to..."
    @user_header = get_user_header(@user.checked_clipboard_contacts)

    #MGS- is the clipboard max-ed out?
    @clipboard_full = (@selected_clipboard_contacts.length >= CONTACT_CLIPBOARD_LIMIT) ? true : false
    @planner = @user.planner
    #MGS- Collect all of the plans from all of the planners we're interested in
    @new_plan_infos, @fuzzy_plan_infos, @solid_plan_infos = PlanDisplay.collect_plan_infos(@user, @planner, @user.checked_clipboard_contacts)
  end

  def dashboard
    #MGS- initalize all the views
    @user = current_user
    @planner = @user.planner
    @planner.set_plans_time_filter(@user)
    user_plans = @planner.plans

    #MGS- initialize the plan info arrays/hashes we'll need
    @user_plan_infos = []
    @new_plan_infos = []
    #MGS- changing to hash, so we can check duplicates
    @friends_plans_to_display = {}
    @all_plans = []

    store_location

    user_plans.each do | pln |
      tentative = (pln.cal_pln_status.to_i == Plan::STATUS_INVITED)
      #MGS- We don't want to show rejected plans
      if pln.accepted? && pln.fuzzy_start
        @user_plan_infos << PlanDisplay.new(pln, Planner::USER_VISIBILITY_LEVEL_OWNER, @planner.owner, @planner.id, tentative)
      elsif Plan::STATUS_INVITED == pln.cal_pln_status.to_i && pln.fuzzy_start
        @new_plan_infos << PlanDisplay.new(pln, Planner::USER_VISIBILITY_LEVEL_OWNER, @planner.owner, @planner.id, true)
      end
    end

    @new_plan_infos.sort!
    #MGS- sort the user's plans and only return the next 5 plans
    @user_plan_infos.sort!
    @user_plan_infos = @user_plan_infos.first(5)

    #MGS- initalize friends plans...which is now friends+contacts plans (fixes #1052)
    friends = @user.friends_and_contacts
    if !friends.nil?
      friends.each do | friend |
        cal = friend.planner
        cal.set_plans_time_filter(@user)
        vis = cal.visibility_level(current_user)
        cal.visible_plans(@user.id).each do | pln |
         #MES- We only want to show confirmed plans, and we
         #  only want to show plans that aren't ALREADY being
         #  shown in all_plan_displays
          if pln.accepted? && !user_plans.include?(pln)
            if @friends_plans_to_display.has_key?(pln.id)
              #MGS- handle the case where the plan already exists in the hash
              plan_info = @friends_plans_to_display[pln.id]
              plan_info.add_attendee(friend)
              plan_info.update_visibility(vis, cal.id)
            else
              #MGS- this plan doesn't exist in the hash...add it
              @friends_plans_to_display[pln.id] = PlanDisplay.new(pln, vis, friend, cal.id, false)
            end
          end
        end
      end
    end

    #MGS- sort the friends's plans and only return the next 5 plans
    @friends_plans_to_display = @friends_plans_to_display.values.sort.first(5)

    #MGS- initalize everyones plans
    latest_plans = Plan.find_latest_plans(@user)
    latest_plans.each do | pln |
      #MGS- TODO this could be more efficient
      if !user_plans.include?(pln) && !@friends_plans_to_display.collect{|p| p.plan.id}.include?(pln.id)
         @all_plans << PlanDisplay.new(pln, Planner::USER_VISIBILITY_LEVEL_DETAILS, User.find(pln.planner_id), pln.planner_id, false)
      end
    end

    #MGS- exclude the current_user's changes and list a max of 10 items
    num_pc_to_show = 10
    pc_orig = PlanChange.find_recent(current_user, true, num_pc_to_show * 2)
    #MES- We don't want to show MULTIPLE status change entries for a single user,
    # e.g. we don't want to show 'smeddy accepted' and 'smeddy rejected'.  Trim out
    # the extras here
    users_rsvp_seen = {} #MES- This is a map of maps.  User_id is the key to the "outer" map, while plan_id is the key to the "inner" maps.
    @plan_changes = []
    pc_orig.each do | pc |
      #MES- If we've already found enough changes, we're done
      break if @plan_changes.length >= num_pc_to_show
      #MES- If it's NOT an RSVP or we haven't seen an RSVP for this user, show it
      if PlanChange::CHANGE_TYPE_RSVP != pc.change_type || (!users_rsvp_seen.has_key?(pc.owner_id) || !users_rsvp_seen[pc.owner_id].has_key?(pc.plan_id))
        @plan_changes << pc
        #MES- If it IS an RSVP, record that we've seen an RSVP for this user.
        if PlanChange::CHANGE_TYPE_RSVP == pc.change_type
          users_rsvp_seen[pc.owner_id] ||= {}
          users_rsvp_seen[pc.owner_id][pc.plan_id] = true
        end
      end
    end

  end

  def plans_history
    #MGS- view of rejected and past plans
    @rejected_plan_infos = []
    @past_plan_infos = []
    @cancelled_plan_infos = []

    store_location
    now = current_timezone.now

    @user = current_user
    @planner = @user.planner
    @user_plans = @planner.plans

    tz = @user.tz
    utc_day_begin = tz.local_to_utc(tz.now.day_begin)
    @user_plans.each do | pln |
      #MGS- build the collections of rejected and past plans
      # past plans are all plans (including rejected) that are in the past
      if pln.involved? && (pln.fuzzy_start < utc_day_begin)
        @past_plan_infos << PlanDisplay.new(pln, Planner::USER_VISIBILITY_LEVEL_OWNER, @planner.owner, @planner.id, false)
      end
      # rejected plans are rejected plans in the future
      if pln.rejected? && pln.fuzzy_start >= now
        @rejected_plan_infos << PlanDisplay.new(pln, Planner::USER_VISIBILITY_LEVEL_OWNER, @planner.owner, @planner.id, false)
      end
      #MES- Look for cancelled plans.  Technically, ALL users on the plan
      #  have to have a status of cancelled for the plan to be cancelled,
      #  but all users should either be cancelled or not cancelled, so
      #  we'll just check the current user.
      if pln.cancelled?
        @cancelled_plan_infos << PlanDisplay.new(pln, Planner::USER_VISIBILITY_LEVEL_OWNER, @planner.owner, @planner.id, false)
      end
    end

    @rejected_plan_infos.sort!
    @past_plan_infos.sort!
    @cancelled_plan_infos.sort!
  end


  def accept_plan
    accept_plan_helper(params, Plan::STATUS_ACCEPTED)
  end

  def express_interest_in_plan
    accept_plan_helper(params, Plan::STATUS_INTERESTED)
  end

  def accept_plan_helper(params, plan_status)
    check_security(params[:id])
    plan = Plan.find(params[:pln_id])
    #MGS- if the request is coming from the dashboard, we pass a special parameter
    # so we know where to redirect to.
    redirect = params[:go_to]
    comment = params[:rsvp_comment]
    #MGS- additional check to ensure user can accept this plan
    check_plan_access(plan)

    Planner.find(params[:id]).accept_plan(plan, current_user, nil, plan_status, comment)

    flash[:notice] = "You've got new plans!"

    #MGS- for requests coming from the dashboard, we want to redirect to the schedule details
    # page and YFT; all other requests (plan_details), should redirect to the plan details page
    if 'dashboard' == redirect
      add_yft_to_flash("plan-list-#{plan.id}")
      redirect_to :controller => 'planners', :action => 'schedule_details', :id => params[:id]
    else
      redirect_to :controller => 'plans', :action => 'show', :id => plan.id, :cal_id => params[:id]
    end
  end

  def reject_plan
    check_security(params[:id])
    plan = Plan.find(params[:pln_id])
    comment = params[:rsvp_comment]
    #MGS- additional check to ensure user can reject this plan
    check_plan_access(plan)
    Planner.find(params[:id]).reject_plan(plan, comment)

    flash[:notice] = 'Removed plans from schedule.'
    redirect_back
  end

  def check_security(cal_id)
    #MES- Currently, a user may only edit their own
    #  planner.  An admin may edit any planner.
    cal_id = cal_id.to_i
    usr = current_user
    if cal_id != usr.planner.id
      #MES- TODO: Raising isn't so great, as it shows an ugly
      #  runtime error to the user.  We should probably redirect
      #  to an error page or something similar.
      raise "User #{usr.id} does not have rights to edit planner #{cal_id} (the planner for user #{usr.id} is #{current_user.planner.id})"
    end
  end

  def check_plan_access(plan)
    if !plan.planners.include?(current_user.planner)
      #MGS- additional security check to make sure that a user is on the plan
      # before accepting or rejecting it
      raise "User #{current_user.id} does not have rights to modify the invitee list for plan #{plan.id}"
    end
  end

###############################################################
########  Methods available to Ajax
###############################################################

  def edit_clipboard_status_ajax
    #MGS - handler for AJAX call when contact checkbox is clicked
    # passes contact_id and status as true or false depending on checkbox selection
    @user = current_user
    begin
      clipboard_status = params[:status] == "true" ? User::CLIPBOARD_STATUS_CHECKED : User::CLIPBOARD_STATUS_SELECTED
      @user.add_or_update_contact(params[:contact_id], { :clipboard_status => clipboard_status })

      sel_contacts = @user.selected_clipboard_contacts
      #MGS- is the clipboard max-ed out?
      @clipboard_full = (sel_contacts.length >= CONTACT_CLIPBOARD_LIMIT) ? true : false

    rescue
      render(:text => "There was a problem changing this contact status.", :status => AJAX_HTTP_ERROR_STATUS)
      return
    end

    @selected_clipboard_contacts = @user.selected_clipboard_contacts
    @planner = @user.planner
    #MGS- Collect all of the plans from all of the planners we're interested in
    @new_plan_infos, @fuzzy_plan_infos, @solid_plan_infos = PlanDisplay.collect_plan_infos(@user, @planner, @user.checked_clipboard_contacts)

    render(:partial => "schedule_details_groupings")
  end

  def remove_contact_from_clipboard_ajax
    begin
      @user = current_user
      #MES- No need to check security- you can always remove a contact from yourself
      @user.add_or_update_contact(params[:contact_id], { :clipboard_status => User::CLIPBOARD_STATUS_NONE })

      if ('true' != params[:refresh])
        render(:nothing => true)
        return
      end

      @selected_clipboard_contacts = @user.selected_clipboard_contacts
      @planner = @user.planner
      #MGS- Collect all of the plans from all of the planners we're interested in
      @new_plan_infos, @fuzzy_plan_infos, @solid_plan_infos = PlanDisplay.collect_plan_infos(@user, @planner, @user.checked_clipboard_contacts)
    rescue Exception => e
      render(:text => "There was a problem removing this contact.  Please refresh the page.", :status => AJAX_HTTP_ERROR_STATUS)
      return
    end
    render(:partial => "schedule_details_groupings")
  end

  def add_contact_to_clipboard_ajax
    #MES- No need to check security- you can always add a contact to yourself
    expanded_name = params[:contact_id]
    screen_name = UserHelper.convert_expanded_to_screen_name(expanded_name)

    usr = User.find_by_string(screen_name)
    #MGS- add the user as checked
    current_user.add_or_update_contact(usr, { :clipboard_status => User::CLIPBOARD_STATUS_SELECTED })

    @selected_clipboard_contacts = current_user.selected_clipboard_contacts
    @selected_clipboard_contacts.each do | ctct |
      if ctct.id == usr.id
         @contact = ctct
         break
      end
    end
    #MGS- is the clipboard maxed out?
    @clipboard_full = (@selected_clipboard_contacts.length >= CONTACT_CLIPBOARD_LIMIT) ? true : false

    render(:partial => "contact", :locals => {:contact => @contact})
  end

  def user_contacts
    @user = User.find(params[:id])
    if @user.nil?
      raise "Error displaying /planners/user_contacts.   Could not open a user object for user_id '#{params[:id]}'"
    end
    #MGS- get the combined collection of friends and contacts
    # and sort the users to bring those who have avatars to the
    # top of the list.
    @combined_contacts = @user.friends_and_contacts.sort{ | a, b |
      (a.thumbnail.nil? ? 1:0) <=> (b.thumbnail.nil? ? 1:0)
    }

    #MGS- get the user's random places
    @random_places = Place.find_user_random_places(@user.id)
  end

###############################################################
########  Helpers for comments
###############################################################
  def delete_comment_ajax
    #MGS- delete comment given user and comment ids
    user_id = params["user_id"]
    comment_id = params["comment_id"]

    comment = Comment.find(comment_id)
    @user = User.find(user_id)
    comments = @user.comments
    #MGS- we need to get by the security check in the comment model that only allows
    # the owner of the comment to delete it;  we really are doing a security check here
    # by ensuring the current user is on their own profile page
    bypass_security = @user == current_user ? true: false
    comment.delete_from_collection(current_user, comments, bypass_security)
    render(:partial => "comments/comments", :object => comments)
  end

  def add_comment_ajax
    #MGS- delete comment given user and comment ids
    user_id = params["user_id"]
    comment_body = params["comment_tb"]

    @user = User.find(user_id)
    comments = @user.comments
    #MGS- create comment, fill it with stuff, and save it
    comment = Comment.new()
    #MGS- TODO figure out if we want people to save empty comments
    comment.body = comment_body
    comment.owner_id = current_user_id
    if comment.save
      @user.comments << comment
      #MGS- check notification settings for the user who's profile we are commenting to
      #MGS- don't send a notification if the current user is making a comment on their own profile
      if @user.get_att_value(UserAttribute::ATT_REMIND_BY_EMAIL) == UserAttribute::TRUE_USER_ATT_VALUE &&
          @user.get_att_value(UserAttribute::ATT_USER_COMMENTED_NOTIFICATION_OPTION) == UserAttribute::TRUE_USER_ATT_VALUE &&
          @user != current_user
        #MGS- send a comment notification if the save was successful
        UserNotify.deliver_user_comment_notification(@user, comment)
      end
    end
    #MGS- sort the comments
    render(:partial => "comments/comments", :object => @user.comments.sort)
  end

  def edit_comment_ajax
    #MGS- edit this comment
    comment_id = params["comment_id"]
    #MGS- this param is suffixed with the comment id for uniqueness
    comment_body_param = "comment_edit_tb" + comment_id
    comment_body = params[comment_body_param]
    user_id = params["user_id"]
    @user = User.find(user_id)

    comment = Comment.find(comment_id)
    comment.body = comment_body
    if comment.update_attributes(params[:comment])
      #MGS- force a reload of the comments to get the updated collection
      render(:partial => "comments/comments", :object => @user.comments.reload)
    end
  end

  #MGS- Returns the title of the section of the page that displays comments
  def comments_section_title
    "I'm the talk of the town"
  end

  #MGS- Returns the ID of the object that the comment refers to (i.e. the id
  # of the place that is being displayed.)
  def parent_of_comment_id
    @user.id
  end

  #MGS- Returns the ID for the form element that will hold the identifier
  # of the item holding the comment
  def parent_of_comment_form_item
    'user_id'
  end

  #MGS- returns the number of comments to group at
  def comment_display_limit
    return PROFILE_MAX_COMMENTS
  end

  #MGS- should add comment access be allowed for this user viewing this page
  def check_add_comment_access
    if @user.friends_and_contacts.include?(current_user) || current_user == @user
      return true
    else
      return false
    end
  end

  #MGS- returns the string to display when there are no comments
  def blank_comments_message
    return "Be the first to say something about #{@user.display_name}."
  end

  def delete_comment?(comment)
    #MGS allow user to delete comments off their profile page,
    # or allow the creator of the comment to delete it
    if current_user == @user || current_user == comment.owner
      return true
    else
      return false
    end
  end

  private
###############################################################
########  Set the static includes
###############################################################
  #MGS- sets the instance variable for js to include
  # needs to include both planner and plans (for inplace plan editing)
  def set_static_includes
    @javascripts = [JS_SCRIPTACULOUS_SKOBEE_DEFAULT, JS_SKOBEE_PLANNERS, JS_SKOBEE_PLANS, JS_SKOBEE_COMMENTS]
  end
end
