class PlansController < ApplicationController
  require 'parsedate'
  require 'erb'
  require 'json'

  include ERB::Util
  include ActionView::Helpers::TextHelper

  helper :application
  helper :plans

  before_filter :login_required, :set_static_includes, :conditional_login_required

  SHOW_PLAN_TEMPLATES = {
    Planner::USER_VISIBILITY_LEVEL_AVAILABILITY => 'plan_availability',
    Planner::USER_VISIBILITY_LEVEL_DETAILS => 'plan_details',
    Planner::USER_VISIBILITY_LEVEL_OWNER => 'plan_owner_view',
  }

  PLACE_ID_NEW_PLACE = -1

  #KS- use these constants to figure out which input field the user used to choose a place
  PLACE_FOUND_BY_NAME = 0
  PLACE_FOUND_BY_ADDRESS = 1
  PLACE_NEW_PLACE = 2

  #MGS- constants for the different types of comment editing levels
  COMMENT_ACCESS_LEVEL_NONE = 0
  COMMENT_ACCESS_LEVEL_FULL = 1

  #MGS- string to display when a user who is not on the invite list, views a plan with a private place
  PRIVATE_PLACE_DISPLAY_TEXT = 'The location is private for now...'

  #MGS- limit at which we switch from displaying thumbnails to text names in the invitee list
  PLAN_THUMBNAIL_DISPLAY_LIMIT = 10


  #MGS- limit the hcal search area to the 2 mile area from where the address geocodes
  HCAL_PLACE_SEARCH_RADIUS = 2

  def login_required_for?(action)
    #KS- the 'did_not_create' and 'undo_email_plan_creation' functions are not
    #protected by login -- they will use a token to see if the user's legit.
    #MES- plan/show is publicly visible- no login required
    return false if ['did_not_create', 'undo_email_plan_creation', 'show', 'pictures_nocache', 'pictures_cached'].include?(action)
    return true
  end

  def conditional_login_required_for?(action)
    #MES- OK- this is kinda weird.  Conditional login is NOT required for show.  Show is
    # available to unauthenticated users.  BUT, if they've supplied conditional login info, we
    # want to user it.  So, if the action is show and they're either conditionally logged in OR
    # it's possible to conditionally log them in, we pretend that we require conditional login.
    return true if ['show'].include?(action) && (logged_in? || conditionally_logged_in? || conditional_login_via_key)
    return false
  end

  def conditional_login_requirement_met?(action_name, current_user_conditions)
    #MES- We only support 'show', so we don't really have to think about
    # action_name right now.

    #MES- Check that current_user_conditions includes the plan we want- that is,
    # the string returned by conditional_item_for_plan
    plan_id = params[:id]
    expected_item = UserNotify.conditional_item_for_plan(plan_id)

    return true if current_user_conditions.include?(expected_item)

    #MES- No dice!
    return false
  end

  def store_loc_before_authenticate?(action_name)
    #MES- If the user got to an AJAX action, but isn't logged in, we do NOT
    # want to store their location- we do NOT want to redirect back to the
    # AJAX action.
    return false if ['add_change_ajax', 'edit_change_ajax', 'delete_change_ajax', 'search_venues_ajax'].include?(action_name)

    return true
  end


  def show
    #MES- When viewing a plan, you may be viewing it from YOUR planner,
    #  in which case you can see everything.  Alternately, you may be
    #  viewing it from another user's planner, in which case
    #  your ability to see details is determined by the security on the
    #  planner.  Finally, you may be viewing it unauthenticated, in which case
    #  visibility is controlled by the planner visibility.
    #MGS- Don't always restrict security when the cal_id param is on the querystring,
    #  if the plan is on your planner, show the owner visiblity level
    @user = current_user
    @plan = Plan.find(params[:id])
    if params[:cal_id] && (@user.nil? || !@user.planner.plans.include?(@plan))
      #MES- If the plan isn't public, we can't see it
      if @plan.security_level != Plan::SECURITY_LEVEL_PUBLIC
        raise "Error: plan #{params[:id]} is not publicly viewable"
      end
      cal = Planner.find(params[:cal_id])
      #MES- If the plan isn't on the planner, then we've been handed incorrect info!
      if !cal.plans.include?(@plan)
        #MES- TODO: Rework error handling- raising to the user isn't nice.
        raise "Error: planner #{params[:cal_id]} doesn't contain plan #{params[:id]}"
      end

      #MES- Choose the correct subtemplate for this user, based on the visibility level
      @subtemplate = SHOW_PLAN_TEMPLATES[cal.visibility_level(@user)]
    else
      #MES- No cal id passed in, and the plan is on the planner of the current user- viewing it on their
      # own planner.
      if !params[:cal_id]
        #MGS- if not conditionally logged in, and there's no cal_id on the querystring
        # log a error so we can trace back any bad links
        logger.error "**** Error in plans/show.  No cal_id was passed on the querystring.  URL requested=#{@request.request_uri} Referrer URL=#{@request.env["HTTP_REFERER"]} ****"
      end

      @plan = check_security(params[:id], false)
      #MES- When viewing your own planner, your visibility is "owner"
      @subtemplate = SHOW_PLAN_TEMPLATES[Planner::USER_VISIBILITY_LEVEL_OWNER]
    end

    #KS- get popular places for sidebar
    @popular_this_week = Place.find_popular_by_day(@user)

    store_location

    #MES- Do we have the info to show an in-place map?
    if @plan.place
      @show_map = (@plan.place.lat && @plan.place.long)
    else
      @show_map = false
    end

    #MGS- get the comment access level for this plan
    @comment_access = @plan.comment_access_level(@user)

    #MGS- check to make sure the current user has accepted this plan, before showing the inplace edit links
    user_cal = @user.nil? ? nil : @user.planner
    @show_edits = @plan.can_edit?(user_cal)

    #MES- Is the plan cancelled?  If every invitee has the cancelled status, then
    #  it's cancelled.
    @cancelled = @plan.cancelled?
    #MES- Never show edits for cancelled plans- that's just weird
    @show_edits = false if @cancelled

    #MES- Record that this user saw this plan at this time
    user_cal.viewed_plan(@plan) if !user_cal.nil?

    #MES- Is there a chance that we have photos?  That is, has any user
    # on the plan added photo integration info (e.g. a Flickr account name)?
    @show_photo_tag_editor = (!@user.nil? && !@user.get_att_value(UserAttribute::ATT_FLICKR_ID).nil?)
    @could_have_photos = @plan.could_have_photos?
    @show_photo = @show_photo_tag_editor || @could_have_photos

    #MES- Should we show the lock/unlock control?  Owners see the control.
    @show_lock_ctl = (@show_edits && @plan.is_owner?(@user.planner))
  end

  #MES- Some tricky stuff to cache pictures.
  # NOTE: This does NOT work unless config.cache_classes in the config
  # is set to TRUE.  For a vanilla development server, classes are not
  # cached, so the cache below is thrown away on every request
  # NOTE: The size of this cache may get large for systems with lots of
  # plans, so this may need to be rethought when Skobee gets big.
  @@pictures_cache = {}

  #MES- Returns the HTML to display pictures for the plan, but does NOT
  # use a cache.  It WILL update the cache if it's stale.
  def pictures_nocache
    plan_id = params[:id]
    str = pictures_helper(plan_id)

    #MES- Is there a cache entry?
    cache_entry = @@pictures_cache[plan_id]
    if !cache_entry.nil?
      #MES- Is it stale?
      if cache_entry != str
        #MES- It's stale, reset it
        @@pictures_cache[plan_id] = str
      end
    end
    render :text => str
  end

  #MES- Returns the HTML to display pictures for the plan, using the cache
  # if there's an appropriate entry.
  # If the HTML is returned from the cache, this method ALSO appends a bit
  # of JavaScript that'll update the HTML again, using the pictures_nocache
  # method.  This way, the user sees results from cache when possible, but
  # display of a stale cache entry is re-rendered with fresh content.
  def pictures_cached
    plan_id = params[:id]
    #MES- Can we find the pictures sidebar text in the cache?
    cache_entry = @@pictures_cache[plan_id]
    str = ''
    if cache_entry.nil?
      #MES- The pictures sidebar is NOT in the cache, get the string and
      # put it in the cache
      str = pictures_helper(plan_id)
      @@pictures_cache[plan_id] = str
    else
      #MES- The pictures sidebar IS in the cache- get the string
      str = cache_entry
      #MES- The cache entry MAY be stale, so append some JavaScript that'll update the
      # HTML
      str += render_to_string(:partial => 'pictures_cached_javascript')
    end
    render :text => str
  end

  #MES- A helper that returns HTML for pictures that are related to the plan
  def pictures_helper(plan_id)
    @plan = Plan.find(plan_id)
    @photo_info = @plan.flickr_photos_info(current_timezone)
    return render_to_string(:partial => 'pictures_async')
  end

  def set_flickr_tags
    @plan = check_security(params[:id])

    #MES- Set the flickr tags based on the post
    @plan.flickr_tags = params[:flickr_tags]
    @plan.save!

    redirect_to(:action => :show, :id => @plan, :cal_id => current_user.planner.id)
  end

  def did_not_create
    #KS- try to authenticate them by token
    user = User.authenticate_by_token(@params['user_id'], @params['token'])

    #KS- authentication not successful, redirect them to login
    if user.nil?
      redirect_to :controller => 'users', :action => 'login'
    end

    @user = user
    @token = @params['token']
    @plan = Plan.find(@params['id'])

    #MES- If they did not create the plan, then they got here in error
    if !@plan.is_owner?(@user.planner)
      raise "User #{@user.id} does not have the right to cancel plan #{@plan.id}"
    end
  end

  def undo_email_plan_creation
    #KS- try to authenticate them by token
    user = User.authenticate_by_token(@params['user_id'], @params['token'])

    #KS- authentication not successful, redirect them to login
    if user.nil?
      redirect_to :controller => 'users', :action => 'login'
      return
    end

    #MES- If they did not create the plan, then they got here in error
    plan = Plan.find(@params['id'])
    if plan.nil? || !plan.is_owner?(user.planner)
      raise "User #{user.id} does not have the right to cancel plan #{@params['id']}"
    end

    #KS- if delete_plan was checked, delete the plan
    if @params['delete_plan'] == 'on'
      #KS- i figure we should actually delete instead of cancelling because
      #if they really didn't create it then they don't want it clogging up their
      #deleted and past plans stuff
      Plan.delete(@params['id'])
    end

    #KS- if disallow_plan_creation_via_email was checked, turn off email plan
    #creation for this user
    if @params['disallow_plan_creation_via_email'] == 'on'
      user.set_att(UserAttribute::ATT_ALLOW_PLAN_CREATION_VIA_EMAIL, 0)
    end
  end

  def new
    #MES- Note: No need to check security here, everyone can create plans
    @plan = Plan.new

    #MGS- set the default place if place passed on querystring
    if params[:place]
      place_id = params[:place].to_i
      place = Place.find_by_id(place_id)
      @plan.place = place
    else
      @plan.place = Place.new
    end

    if params[:who]
      #MGS- currently only supports one user being passed on the querystring
      invitee_id = params[:who].to_i
      invitee = User.find_by_id(invitee_id)
      #MGS- adding a comma space, so the who field is primed for further input
      @who_field_txt = "#{h(invitee.full_name_and_login)}, "
    end

    #MGS- set the default dateperiod and timeperiod for a new plan
    @plan.set_datetime current_timezone, Plan::DEFAULT_DATE, Plan::DEFAULT_TIME

    #MES- Get the other info the view needs
    @popular_this_week = Place.find_popular_by_day(current_user)
    #MES- Get one more regular than we really want, so we can tell if we
    # should show a "more" link
    @regulars = User.find_regulars(current_user, 11)
    @more_regulars = false
    if 11 == @regulars.length
      @more_regulars = true
      @regulars.pop
    end


    #KS- set place in the flash
    flash[:place] = @plan.place
  end

  #MGS- NOTE: This is a copy of 'new'.  if this will exist long-term, they
  # should be rolled into one function.
  def new_hcal
    #MES- Note: No need to check security here, everyone can create plans
    @plan = Plan.new
    #MGS- strip whitespace from the name and description fields
    @plan.name = params[:name].to_s.strip
    @plan.description = params[:desc].to_s.strip

    #MGS- search for the place passed in the querystring
    place_name = params[:place_name]
    place_location = params[:place_location]

    if !place_name.blank?
      #MGS- if there is no location passed in, we start the search from the current user's zipcode
      place_location = current_user.get_att_value(UserAttribute::ATT_ZIP) if place_location.blank?
      #MGS- use the location of the place to serve as the center of the search
      bounding_box = GeocodeCacheEntry.get_bounding_box_array(place_location, HCAL_PLACE_SEARCH_RADIUS)

      if !bounding_box.nil?
        @search_results = Place.find_by_name_prox_time(
                                                      current_user,
                                                      place_name,
                                                      bounding_box,
                                                      HCAL_PLACE_SEARCH_RADIUS,
                                                      nil, #timezone, -not used
                                                      nil, #day_array,
                                                      nil, #begin_time,
                                                      nil, #duration,
                                                      false, #include_private
                                                      10,
                                                      0)
        #MGS- if results were returned for this place name/location, take the first result for now
        # otherwise, just default to a new place
        if @search_results.length > 0
          @plan.place = @search_results[0]
        else
          #MGS- if we couldn't find a place, flash an error
          flash.now[:error] = "Place not found."
          @plan.place = Place.new
        end
      else
        #MGS- bounding box nil
        flash.now[:error] = "Place not found."
        @plan.place = Place.new
      end
    end

    #MGS- set the default dateperiod and timeperiod for a new plan
    @plan.set_datetime current_timezone, Plan::DEFAULT_DATE, Plan::DEFAULT_TIME

    #MGS- check to see if a start date is passed
    if params[:dtstart]
      plan_start = params[:dtstart]
      dtstart =  Time.parse(plan_start)
      #MGS- assume all times are passed in UTC;  this unfortunately is not always the case
      # upcoming.org passes times in UTC, but eventful does not.  Since we are writing this
      # feature for Yahoo, we only care about UTC for now.
      local_dtstart = current_timezone.utc_to_local(dtstart)

      #MGS- check to see if the date is in a format: 2006-12-12 with no time
      # if so, default the time to ALL_DAY
      m = plan_start.match(/^\d{4}\-\d{2}\-\d{2}$/)
      if m.nil?
        #MGS- hours and minutes were parsed out of the date string
        date_info = [local_dtstart.year, local_dtstart.mon, local_dtstart.day]
        time_info = [local_dtstart.hour, local_dtstart.min, 0]
      else
        #MGS- if no time could be parsed out of this event, most likely one wasn't passed
        # treat this as an all day event
        #MGS- if we get just a yyyy-mm-dd string, assume this time is in local time, as this is how
        # upcoming.org seems to work
        date_info = [dtstart.year, dtstart.mon, dtstart.day]
        time_info = Plan::TIME_DESCRIPTION_ALL_DAY
      end
      @plan.set_datetime current_timezone, date_info, time_info
    end

    if params[:who]
      #MGS- currently only supports one user being passed on the querystring
      invitee_id = params[:who].to_i
      invitee = User.find_by_id(invitee_id)
      #MGS- adding a comma space, so the who field is primed for further input
      @who_field_txt = "#{h(invitee.full_name_and_login)}, "
    end

    #MES- Get the other info the view needs
    @regulars = User.find_regulars current_user
    @popular_this_week = Place.find_popular_by_day(current_user)

    #KS- set place in the flash
    flash[:place] = @plan.place
    render :action => 'new'
  end

  #MES- NOTE: This is a copy of 'new'.  if this will exist long-term, they
  # should be rolled into one function.
  def new_plaxo
    #MES- Note: No need to check security here, everyone can create plans
    @plan = Plan.new

    @plan.place = Place.new

        #MES- The who parameter is just the String we want.
    if params[:who]
      @who_field_txt = params[:who]
    end

    if params[:what]
        @plan.name = params[:what]
    end

    #MGS- set the default dateperiod and timeperiod for a new plan
    @plan.set_datetime current_timezone, Plan::DEFAULT_DATE, Plan::DEFAULT_TIME

    #MES- Get the other info the view needs
    @regulars = User.find_regulars current_user
    @popular_this_week = Place.find_popular_by_day(current_user)

    #KS- set place in the flash
    flash[:place] = @plan.place

    render :action => 'new'
  end

  def create
    #MES- Note: No need to check security here, everyone can create plans
    @plan = Plan.new(params[:plan])

    #MGS- error flag for form validation
    @validation_error = false

    fix_time_post!(params, true)
    invited_to_add = process_invites_no_notifications!(params)
    process_place!(params)

    render_new = false
    user = current_user
    #MGS- if there's an error in the invitee field; we know we need to render in new before saving
    if @validation_error
      render_new = true
    elsif @plan.save  #MGS- no specific validation error; lets try to save it
      #MES- Put it into the default planner of the current user
      user.planner.accept_plan(@plan, user, Plan::OWNERSHIP_OWNER)
      message = "You've got new plans!"
      if flash[:notice].nil?
        flash[:notice] = message
      else
        flash[:notice] += "<br/>" + message
      end

      #KS- handle notifications after we've set the owner
      handle_invite_notifications(invited_to_add)

      #MGS- always redirect to the plan after creating it; bug #490
      redirect_to :action => 'show', :id => @plan, :cal_id => user.planner.id
    else
      #MGS- problems during the save
      render_new = true
    end

    if render_new
      #MGS- Get the other info the view needs in case validation fails
      @regulars = User.find_regulars user
      @popular_this_week = Place.find_popular_by_day(current_user)
      render :action => 'new'
    end
  end

  def update
    @plan = check_security(params[:id])
    user = current_user
    @plan.checkpoint_for_revert(user)

    #MGS- error flag for form validation
    @validation_error = false

    #MGS- get the grouping, so it can be passed down to the partial
    @group = params[:group]

    fix_time_post!(params)
    process_invites!(params)
    process_place!(params)
    if @plan.update_attributes(params[:plan])
      flash[:notice] = 'Plan was successfully updated.'
    else
      flash[:error] = 'There was a problem updating this plan.'
    end
    #MGS- always redirect to the plan/show page
    redirect_to :action => :show, :id => @plan, :cal_id => current_user.planner.id
  end

  def revert
    @plan = check_security(params[:id])

    #MGS- don't allow user to change revert, unless they've accepted the plan
    if !Plan::STATUSES_ACCEPTED.member?(@plan.planners.find(current_user.planner.id).cal_pln_status.to_i)
      flash[:error] = "Whoops. Can't change the plans when your status is set to I'm Out."
      #MGS- adding cal_id to the querystring, if you can revert, you can see the plan with your own planner
      redirect_to :action => 'show', :id => @plan, :cal_id => current_user.planner.id
      return
    end

    @plan.checkpoint_for_revert(current_user)
    change = PlanChange.find(params[:change_id])

    #MES- Revert the plan to the change
    @plan.revert_from_change(change)
    @plan.save

    #MES- Redisplay the plan
    #MGS- adding cal_id to the querystring, if you can revert, you can see the plan with your own planner
    redirect_to :action => 'show', :id => @plan, :cal_id => current_user.planner.id
  end

  def sidebar_touchlist
    @touchlist = User.find_regulars(current_user, 250, true)
    @show_less = true
    #MES- Don't display the 'show less' link if the QueryString said not to
    @show_less = false if ('false' == @params[:show_less])
    render :partial => 'sidebar_touchlist'
  end

  def sidebar_regulars
    #MES- Get one more regular than we really want, so we can tell if we
    # should show a "more" link
    @regulars = User.find_regulars(current_user, 11)
    @more_regulars = false
    if 11 == @regulars.length
      @more_regulars = true
      @regulars.pop
    end
    render :partial => 'sidebar_regulars'
  end

  def check_security(pln, for_edit = true, user = nil)
    #MES- For most actions, a user may only perform the action
    #  on the plan if the plan appears on their planner
    if !(pln.is_a? Plan)
      pln = Plan.find(pln)
    end

    if user.nil?
      user = current_user
    end

    plnr = user.planner

    #MES- Is this for editing?
    if (for_edit)
      if !pln.can_edit?(plnr)
        raise "User #{user.id} does not have the right to edit plan #{pln.id}"
      end
    else
      if !user.planner.plans.include?(pln)
        raise "User #{user.id} does not have rights on plan #{pln.id} since it does not appear on their planner"
      end
    end

    return pln
  end


###############################################################
########  Methods available to Ajax
###############################################################
  def add_change_ajax
    @plan = Plan.find(params["plan_id"])

    #MES- Create the comment item, using a helper in the plan object
    change_type = PlanChange::CHANGE_TYPE_COMMENT
    change_type = params[:change_type].to_i if params[:change_type]
    @plan.add_comment(current_user, params["change_tb"], change_type)

    @comment_access = @plan.comment_access_level(current_user)
    #MES- Since they're adding a comment, there will be comments, right?
    #  We don't have to handle the "no comments" case
    render(:partial => 'changes', :object => @plan.plan_changes.sort)
  end

  def edit_change_ajax
    #MGS- edit this change comment
    change_id = params["change_id"]

    @plan = Plan.find(params["plan_id"])
    change = PlanChange.find(change_id)
    change.check_security(current_user)
    #MGS- this param is suffixed with the comment id for uniqueness
    change.comment = params["change_edit_tb" + change_id]
    change.save
    @comment_access = @plan.comment_access_level(current_user)
    render :partial => 'changes', :object => @plan.plan_changes
  end

  def delete_change_ajax
    #MGS- delete comment given place and comment ids
    change = PlanChange.find(params['change_id'])
    @plan = Plan.find(params["plan_id"])
    change.delete_from_collection(current_user, @plan.plan_changes)

    @comment_access = @plan.comment_access_level(current_user)
    changes = @plan.plan_changes
    render(:partial => 'changes', :object => changes)
  end

  def auto_complete_for_place_list
    auto_complete_responder_for_place_list params[:place_search]
  end

  def edit_what
    #MGS- called for inplace edit of what field
    @plan = check_security(params[:id])
    @plan.name  = params[:plan_name]
    @plan.description  = params[:plan_description]
    @plan.save
    @show_edits = true
    flash[:notice] = "This plan has been successfully updated."
    redirect_back
  end

  def edit_when
    #MGS- called for inplace edit of when field
    @plan = check_security(params[:id])
    @plan.checkpoint_for_revert(current_user)
    @plan.comment_for_change(params[:comment_tb])

    #MGS- process what we need to process from the form post
    fix_time_post!(params)
    @plan.save

    #MES- NOTE: Not strictly true- we don't send emails to users who have specified that they don't want emails
    flash[:notice] = "Attendees have been notified of the time change via email."
    redirect_back
  end

  def edit_who
    #MGS- called for inplace edit of who field
    @plan = check_security(params[:id])
    @plan.checkpoint_for_revert(current_user)

    @flash_added_invitees = false
    @flash_removed_invitees = false

    process_invites!(params)
    process_remove_invites!(params)

    if !@validation_error
      @plan.save
      #MES- NOTE: Not strictly true- we don't send emails to users who have specified that they don't want emails
      if @flash_added_invitees
        add_message = "Skobee has sent the new invitees an invitation email, which includes a description of this plan."
        if flash[:notice].nil?
          flash[:notice] = add_message
        else
          flash[:notice] += "<br/>" + add_message
        end
      end

      if @flash_removed_invitees
        remove_message = "User(s) successfully removed from the plan."
        if flash[:notice].nil?
          flash[:notice] = remove_message
        else
          flash[:notice] += "<br/>" + remove_message
        end
      end
      redirect_back
    else
      flash[:who_field_txt] = @who_field_txt
      redirect_back
    end
  end

  def edit_where
    #KS- called for inplace edit of where field
    @plan = check_security(params[:id])
    @plan.checkpoint_for_revert(current_user)
    @plan.comment_for_change(params[:comment_pb])

    #KS- do the place processing
    process_place!(params)

    if !@validation_error
      @plan.save
      #MES- NOTE: Not strictly true- we don't send emails to users who have specified that they don't want emails
      flash[:notice] = "Attendees have been notified of the place change via email."
    else
      #KS- set this variable so that in plans/show we know to show the where control
      flash[:place_validation_error] = true
    end

    redirect_back
  end

  def change_privacy
    #MGS- called for inplace edit of privacy
    @plan = check_security(params[:id])

    #MES- Reverse the security of the plan
    new_security = Plan::OTHER_SECURITY[@plan.security_level]
    @plan.security_level = new_security
    @plan.save

    if Plan::SECURITY_LEVEL_PRIVATE == new_security
      flash[:notice] = "This plan is now private.<br/>Only invitees can see the details of this plan."
    else
      flash[:notice] = "This plan is no longer private.<br/>The visibility of this plan is now controlled by the privacy settings of the attendees."
    end
    redirect_back
  end

  def change_lock
    @plan = Plan.find(params[:id])
    #MES- Only the owner can change the lock status
    usr = current_user
    if !@plan.is_owner?(usr.planner)
      #MES- Error!  User is not owner!
      raise "User #{usr.id} does not have the right to edit lock status for plan #{@plan.id}"
    end

    #MES- Reverse the lock status of the plan
    new_lock = Plan::OTHER_LOCK[@plan.lock_status]
    @plan.lock_status = new_lock
    @plan.save

    if Plan::LOCK_STATUS_UNLOCKED == new_lock
      flash[:notice] = "This plan is now unlocked.<br/>All participants can change plan details, such as when or where."
    else
      flash[:notice] = "This plan is now locked.<br/>Only you can change the plan details, such as when or where.  Other participants can still add comments and change their RSVP status."
    end
    redirect_back
  end

  #MES- Used to cancel a plan through the UI- all participants are notified.
  def cancel
    @plan = check_security(params[:id])

    #MES- Which users should we notify?  We want to figure this out
    #BEFORE cancelling the plan, since we only want to notify people who
    #  who are interested in the plan, and after cancelling, we lose
    #  that info
    users_to_notify = []
    @plan.planners.each do | plnr |
      #MES- Is this planner interested in the plan?
      if Plan::STATUSES_ACCEPTED_OR_INVITED.include?(plnr.cal_pln_status.to_i)
        #MES- Does the user want to get email notifications?, and is it NOT the
        #  current user?
        user = plnr.owner
        if user != current_user &&
            UserAttribute::FALSE_USER_ATT_VALUE !=  user.get_att_value(UserAttribute::ATT_REMIND_BY_EMAIL).to_i &&
            UserAttribute::PLAN_MODIFIED_ALWAYS == user.get_att_value(UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION).to_i
          users_to_notify << user
        end
      end
    end

    @plan.cancel

    #MES- Send the notifications
    users_to_notify.each do | user |
      UserNotify.deliver_cancel_plan(current_user, user, @plan)
    end

    flash[:notice] = "This plan is canceled.<br/>Attendees have been notified of the cancellation via email."
    redirect_back
  end

  #MES- Used to uncancel, or reinstate, a plan.  Reverses the action of cancel (more
  #  or less.)
  def uncancel
    @plan = check_security(params[:id])
    @plan.uncancel(current_user)

    #MES- Every user is notified of an uncancel- it's like an
    #  invitation.
    @plan.planners.each do | plnr |
      user = plnr.owner
      if user != current_user &&
          UserAttribute::FALSE_USER_ATT_VALUE !=  user.get_att_value(UserAttribute::ATT_REMIND_BY_EMAIL).to_i &&
          UserAttribute::INVITE_NOTIFICATION_ALWAYS == user.get_att_value(UserAttribute::ATT_INVITE_NOTIFICATION_OPTION).to_i
        UserNotify.deliver_uncancel_plan(current_user, plnr.owner, @plan)
      end
    end
    flash[:notice] = "This plan is reinstated.<br/>All attendees have been re-invited."
    redirect_back
  end

  def search_venues_ajax
    #MGS- used on the new event wizard to search for venues
    # no security check needed as anyone can search for venues
    #MGS- default page results
    @results_per_page = 8
    hash_to_members(params, :days, :fulltext, :location, :max_distance)

    #MGS set the max distance
    if @max_distance == nil || @max_distance.empty?
      max_distance = nil
    else
      max_distance = @max_distance.to_i
      max_distance = PlacesController::DEFAULT_MAX_DISTANCE if max_distance <= 0
    end

    bounding_box = GeocodeCacheEntry.get_bounding_box_array(@location, max_distance)
    #MGS- TODO handle when bounding box is nil
    if bounding_box.nil? && @params[:require_address].to_i == 1
      #MES- The address was no good, tell the user so they can try again.
      render(:text => "The location you entered was not understood.  Please try again.", :status => AJAX_HTTP_ERROR_STATUS)
      return
    end

    #KS- if we're including private venues, pass in the arg to allow it
    include_private = (@params['private_venues_ok'] == 1)
    @count = Place.count_by_name_prox_time(
          current_user,
          @fulltext,
          bounding_box,
          max_distance,
          nil, #timezone,
          nil, #day_array,
          nil, #begin_time,
          nil, #duration
          include_private)

    @params['page'] = @params['page'].nil? ? 1 : @params['page']
    @place_pages = Paginator.new self, @count, @results_per_page, @params['page']
    @search_results = Place.find_by_name_prox_time(
          current_user,
          @fulltext,
          bounding_box,
          max_distance,
          nil, #timezone, -not used
          nil, #day_array,
          nil, #begin_time,
          nil, #duration,
          include_private,
          @place_pages.items_per_page,
          @place_pages.current.offset)

    render(:partial => @params['template'])
  end

  def postpone_plan
    #MGS- delay the start, fuzzy times on the plan a week
    @plan = check_security(params[:id])

    #MGS- extra check to make sure this is only called for fuzzy plans.
    if @plan.fuzzy_start != @plan.start
      #MGS TODO - should we have date math constants?
      # Seems silly to keep repeating stuff like this everywhere
      #MGS- delay both the start and fuzzy start times one week
      @plan.fuzzy_start = @plan.fuzzy_start + (60 * 60 * 24 * 7)
      @plan.start = @plan.start + (60 * 60 * 24 * 7)
      @plan.save
    end

    redirect_back
  end


###############################################################
########  Private helpers
###############################################################


  private

  #KS- takes in an array of entered user identifiers, converts the autocomplete entries
  #from the "[real_name] ([screen_name])" format to [screen_name].
  #Note that we assume neither real names nor screen names are not allowed to contain parentheses.
  def convert_autocompletes_to_screen_names(users)
    users.each {|user|
      user = UserHelper.convert_expanded_to_screen_name(user)
    }
  end

  def auto_complete_responder_for_place_list(value)
    @places = Place.find_for_autocomplete(current_user, value)

    #KS- create a JSON 2d array in the following format:
    #index 0: an array of all the place ids corresponding to the places in the array at index 1
    #index 1: an array of all the place names
    #index 2: an array of all the place address + cities in parens if they both exist
    #KS- note that this array structure is identical to the javascript array written to string
    #in ApplicationHelper#generate_place_autocomplete_array
    place_id_array = Array.new
    place_name_array = Array.new
    place_location_array = Array.new
    place_normalized_name_array = Array.new

    @places.each{ |place|
      place_id_array << place.id
      place_name_array << place.name
      if !place.address.nil? && !place.city.nil?
        place_location_array << " (#{place.address}, #{place.city})"
      else
        place_location_array << ""
      end
      place_normalized_name_array << place.normalized_name
    }

    places_array = [ place_id_array, place_name_array, place_location_array, place_normalized_name_array ]
    json = JSON.unparse(places_array)

    render :text => json
  end

###############################################################
########  Private helpers for handling post data
###############################################################

  def fix_time_post!(params, create = false)
    #KS- don't do anything if there are no relevant parameters -- useful for links
    #that change stuff like place without having to specify all the time crud
    return if !create &&
              params[:timeperiod].nil? &&
              params[:dateperiod].nil? &&
              params[:date_year].nil? &&
              params[:date_month].nil? &&
              params[:date_day].nil? &&
              params[:plan_hour].nil? &&
              params[:plan_min].nil?

    today = current_timezone.now
    #MGS - fuzzy time option is selected
    if 0 != params[:timeperiod].to_i
      #MGS- fuzzy time
      time_info = params[:timeperiod].to_i
    else
      #MGS- exact time
      hour = params[:plan_hour]
      min = params[:plan_min]

      #MGS- we currently have little patience for incorrect times
      # set to TIME_DESCRIPTION_DINNER if the data looks invalid
      #MGS TODO- Currently dont allow 24 hr times, should we?
      if hour.nil? || !(1..12).include?(hour.to_i) || min.nil? || !(0..59).include?(min.to_i)
        time_info = Plan::TIME_DESCRIPTION_DINNER
      else
        hour = Time::correct_hour_for_meridian(hour.to_i, params[:plan_meridian])
        time_info = [hour, min, 0]
      end
    end
    #MGS - fuzzy date option is selected
    if 0 != params[:dateperiod].to_i
      if params[:dateperiod].include? "\/"
        #MGS- handle the special case, where specific dates are included in the dateperiod dropdown
        date_info = ParseDate.parsedate(params['dateperiod'])
      else
        #MGS- fuzzy date
        date_info = params[:dateperiod].to_i
      end
    else
      #MGS- exact date
      year = params[:date_year]
      mon = params[:date_month]
      day = params[:date_day]

      #MGS- a bunch of datehandling here; instead of prompting user's to fix their specific dates,
      # we're going to try to do some pseudo-intelligent defaulting
      #MGS-validate year
      if year.nil? || year.to_i == 0
        #MGS- if the year is blank or some non-numeric value, default it to the current year
        # to_i will return 0 if called on a string that's non-numeric
        # if characters other than numbers are entered, we set the year to the current year
        year = today.year
      else
        #MGS- check the length of the year, if its 2....user must have only entered a two digit year
        # we'll assume they entered the last two digits of the year and handle it accordingly
        if (year.length == 2)
          year = today.year.to_s[1,2] + year
        elsif year.length != 4
          #MGS- if they only entered 1 or 3 digits for the year, they're hopeless....and getting the current year set
          year = today.year
        end
      end

      #MGS- validate month
      if mon.nil? || mon.to_i == 0 || !(1..12).include?(mon.to_i)
        mon = today.mon
      end
      #MGS- validate day
      if day.nil? || day.to_i == 0 || !(1..31).include?(day.to_i)
        day = today.day
      else
        #MGS- do something pretty simple to make sure they entered no more than the right number of days in a month
        # Date.civil doesn't increment the month automatically for you, so using Time.utc
        new_time = current_timezone.utc_to_local(Time.utc(year, mon, day, 12, 0, 0, 0))
        mon = new_time.mon if new_time.mon != mon
        day = new_time.day if new_time.day != day
        year = new_time.year if new_time.year != year
      end
      date_info = [year, mon, day]
    end

    @plan.set_datetime(current_timezone, date_info, time_info)
  end

  def process_invites_no_notifications!(params)
    #MES- If nothing was posted, don't do anything.  This is
    # convenient for testing.
    return if params[:plan_who].nil?

    user_list = params[:plan_who]

    #MGS- split string on commas or semicolons with optional whitespace before or after
    users = user_list.split_delimited_emails()

    #MGS- temporary array - holds valid emails for login generation if all other validation passes
    new_account_emails = Array.new
    #MGS- relevant planners from invitees
    cals_desired = Array.new
    #MGS- array for storing bad values for error message
    invalid_entries = Array.new


    #MGS- remove nil and blank values from array; these values can arise when delimiters are entered without values between them
    users.compact!
    users.delete_if {|user| user == "" }

    #KS- convert all autocompleted strings to screen names
    convert_autocompletes_to_screen_names(users)

    #MGS-  Loop through fields entered into who textarea
    # Logins or email addresses can be entered into this field.  If the entry is an email address
    # this will first attempt to find a login that matches that email address.  If no login is found
    # the email address is stored in a temporary array and a new login is created for that email address
    # but only after all other validation succeeds.
    users.each_index { |i|
      entry = users[i]

      usr = User.find_by_string(entry)
      if usr
        #MGS- valid entry; either a login or an email
        cals_desired << usr.planner
      elsif entry.is_email?
        #MGS- entry looks like an email but doesn't exist in system;
        # store it away for future use
        new_account_emails << entry
      else
          #MGS- invalid entry
          #MGS- TODO add the highlighting spans below
          #users[i] = "$" + entry + "$"

          #MGS- add this entry to the bad entries array, so it can be included in the error message
          invalid_entries << entry
          @validation_error = true
      end
    }

    if @validation_error
      #MGS- flash an error to the user
      flash[:error] = "Unable to recognize username or email address. Entries must be separated by commas (e.g. jack@hill.com, jill@hill.com)"
      #MGS- set the parsed out entries into an instance variable
      #@who_field_txt = users.join(',')
      @who_field_txt = params[:plan_who]
      return
    else #validation passed

      #MGS- remove duplicates, in case people entered the same new email address twice
      new_account_emails.uniq!
      #MGS- create the new user accounts from the email addresses if all other validation passes
      new_account_emails.each do |email|
        usr = User.create_user_from_email_address(email, current_user)
        #MES- Did we make a user?  The current user might not be allowed to invite new users.
        if !usr.nil?
          cals_desired << usr.planner
        end
      end

      #MGS- remove duplicates
      cals_desired.uniq!
    end

    #MGS- the current cals are cals on the plan that have a status of ACCEPTED, REJECTED, or ALTERED
    # or anything but NO_RELATION
    current_cals = @plan.planners.select{|cal| Plan::STATUS_NO_RELATION != cal.cal_pln_status.to_i}

    #MGS- only add people who haven't already accepted, rejected or been invited
    invited_to_add = cals_desired - current_cals
    invited_to_add.each do | cal_to_add |
      @flash_added_invitees = true
      cal_to_add.add_plan(@plan)
    end

    return invited_to_add
  end

  def process_invites!(params)
    invited_to_add = process_invites_no_notifications!(params)

    handle_invite_notifications(invited_to_add)
  end

  def handle_invite_notifications(invited_to_add)
    if !invited_to_add.nil?
      users = []
      invited_to_add.each {| planner | users << planner.owner }
      process_notifications(users, @plan)
    end
  end

  #KS- send out notifications to the users who requested them
  def process_notifications(users, plan)
    users.each{| user |
      #KS- if they have email notification on, check their notification setting
      email_notification = user.get_att_value(UserAttribute::ATT_REMIND_BY_EMAIL)
      if email_notification
        #KS- which notification category does this user fall into?
        notification_setting = user.get_att_value(UserAttribute::ATT_INVITE_NOTIFICATION_OPTION)
        notification_setting = notification_setting.nil? ? nil : notification_setting.to_i
        case notification_setting
          when UserAttribute::INVITE_NOTIFICATION_ALWAYS
            if user.registered?
              UserNotify.deliver_invite_notification(current_user, user, plan)
            else
              url = url_for(:controller => 'users', :action => 'register', :id => user.id)
              UserNotify.deliver_unregistered_invite_notification(current_user, user, plan, url)
            end
        end

      end
      #TODO: KS- handle SMS notification
    }
  end

  def process_remove_invites!(params)
    #MGS- If nothing was posted, don't do anything.
    return if params[:plan_remove_who].nil?
    user_list = params[:plan_remove_who]
    #MGS- split string on commas or semicolons with optional whitespace before or after
    logins_to_remove = user_list.split_delimited_emails()

    logins_to_remove.each do | login |
      usr = User.find_by_string(login)
      planner = usr.planner
      if @plan.planners.include?(planner)
        @flash_removed_invitees = true
        @plan.planners.update_attributes(planner, :cal_pln_status => Plan::STATUS_NO_RELATION)
      end
    end
  end

  def process_place!(params)
    #MES- If nothing was posted, don't do anything.  This is
    # convenient for testing.
    return if params[:place_origin].nil?

    #KS- grab relevant params
    place_origin = params[:place_origin].to_i
    place_id = params[:place_id].to_i
    place_name = params[:place_name]
    place_location = params[:place_location]
    place_phone = params[:place_phone]
    place_url = params[:place_url]
    request_public = (params[:request_public] == "on") ? true : false

    #KS- do different things depending on whether the user picked or added a place
    case place_origin
      when PLACE_FOUND_BY_NAME, PLACE_FOUND_BY_ADDRESS
        place = Place.find(:first, :conditions => ["id = :id", {:id => place_id}])
      when PLACE_NEW_PLACE
        place = Place.new
        place.name = place_name
        place.user_id = current_user_id
        place.location = place_location
        place.phone = place_phone
        place.url = place_url
        place.public_status = Place::PUBLIC_STATUS_REQUESTED if request_public
        if !place.location.nil? && !place.location.empty?
          place.geocode_location!
        end
        if !@validation_error && place.save
          place.save
          flash[:notice] = 'Place was successfully created.'
          if request_public
            flash[:notice] += '<br/>Your new place will be publicly available when approved by a Skobee administrator.'
          end
        else
          flash[:active_tab] = PLACE_NEW_PLACE
          @validation_error = true
          flash.now[:error] = []
          place.errors.each{ |error|
            flash.now[:error] << error[1]
          }
        end
    end

    #KS- put place in the flash for use in error message display
    flash[:place] = place

    @plan.place = place
  end

###############################################################
########  Set the static includes
###############################################################
  #MGS- sets the instance variable for js to include
  def set_static_includes
    @javascripts = [JS_SCRIPTACULOUS_SKOBEE_DEFAULT, JS_SKOBEE_PLANS, JS_DATEPICKER, JS_JSON]
  end

end
