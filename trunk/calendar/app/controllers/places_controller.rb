class PlacesController < ApplicationController

  DAY_MONDAYS = '0'
  DAY_TUESDAYS = '1'
  DAY_WEDNESDAYS = '2'
  DAY_THURSDAYS = '3'
  DAY_FRIDAYS = '4'
  DAY_SATURDAYS = '5'
  DAY_SUNDAYS = '6'
  DAY_WEEKENDS = '5,6'
  DAY_ANY = '-1'

  DAYS_CHOICES = [
    [DAY_ANY, 'Any Day'],
    [DAY_MONDAYS, 'Mondays'],
    [DAY_TUESDAYS, 'Tuesdays'],
    [DAY_WEDNESDAYS, 'Wednesdays'],
    [DAY_THURSDAYS, 'Thursdays'],
    [DAY_FRIDAYS, 'Fridays'],
    [DAY_SATURDAYS, 'Saturdays'],
    [DAY_SUNDAYS, 'Sundays'],
    [DAY_WEEKENDS, 'Weekends'],
  ]
  DAYS_CHOICES_MAP = DAYS_CHOICES.to_hash

  #MES- This is basically identical to Plan::TIME_DESC_TO_ENGLISH, except that
  # the "all day" choice is not offered.
  TIME_CHOICES = [
    [Plan::TIME_DESCRIPTION_ALL_DAY, 'Any Time'],
    [Plan::TIME_DESCRIPTION_EVENING, 'Evening'],
    [Plan::TIME_DESCRIPTION_DINNER, 'Dinner'],
    [Plan::TIME_DESCRIPTION_AFTERNOON, 'Afternoon'],
    [Plan::TIME_DESCRIPTION_LUNCH, 'Lunch'],
    [Plan::TIME_DESCRIPTION_MORNING, 'Morning'],
    [Plan::TIME_DESCRIPTION_BREAKFAST, 'Breakfast'],
  ]

  #MES- The defualt max distance, if the user does a proximity search but doesn't
  # supply a distance, or supplies a bogus distance.
  DEFAULT_MAX_DISTANCE = 5

  before_filter :login_required, :set_static_includes

  def store_loc_before_authenticate?(action_name)
    #MES- If the user got to an AJAX action, but isn't logged in, we do NOT
    # want to store their location- we do NOT want to redirect back to the
    # AJAX action.
    return false if ['delete_comment_ajax', 'add_comment_ajax', 'edit_comment_ajax'].include?(action_name)

    return true
  end
  
  def login_required_for?(action)
  	#MES- 'show' does not require login
    return false if 'show' == action
    return true
  end

  def show
    @place = Place.find(params[:id])
    check_read_access(@place, params[:plan_id])

    # MGS store the current location, so after creating comment redirects back
    store_location

    #MES- Do we have the info to show locations?
    @show_loc = !@place.location.blank?

    #MES- Do we have the info to show an in-place map?
    @show_map = (@place.lat && @place.long)

    #MES- Should this user see the 'edit' link?
    @show_edit = (current_user_id == @place.user_id && @place.public == Place::PLACE_PRIVATE)

    @recent_plans = Plan.find_at_place(@place, 3)
    @recent_attendees = User.find_attended_place(@place, 6)

    #MES- Get and format the daily stats for the place
    raw_stats = @place.daily_stats
    #MES- Digest the day_stats into something that the UI can easily show
    @digested_stats = {}
    max = raw_stats['max']
    max = 1 if max == 0
    0.upto(6) do | index |
      @digested_stats[index] = ((raw_stats[index].to_f/max.to_f) * 100).to_i
    end
  end

  def new
    @place = Place.new
  end

  def create
    @place = Place.new(@params[:place])

    #KS- set the user id to the current user's id
    @place.user_id = current_user.id

    @place.public = Place::PLACE_PRIVATE
    if @params[:place]['public_status'] == '1'
      @place.public_status = Place::PUBLIC_STATUS_REQUESTED
    end

    #KS- validate the location separately (we have to allow blank
    #locations outside of this method because of email plan
    #creation i think)
    @place.validate_location

    if @place.save && @place.errors.empty?
      flash[:notice] = 'Place was successfully created.'
      if Place::PUBLIC_STATUS_REQUESTED == @place.public_status
        flash[:notice] += '<br/>Your new place will be publicly available when approved by a Skobee administrator.'
      end
      redirect_to :action => 'show', :id => @place.id
    else
      render :action => 'new'
    end
  end

  def edit
    @place = Place.find(@params[:id])
    check_write_access(@place)

    #KS- render if no data is posted
    return if :post != @request.method

    #KS- error if the current user id doesn't match the place owner
    if @place.user_id != current_user.id
      flash[:error] = 'You must be the owner of a place to edit it.'
      return
    end

    #KS- error if the place is public
    if @place.public != Place::PLACE_PRIVATE
      flash[:error] = 'You cannot edit a public place.'
      return
    end

    #KS- set public status requested if the checkbox was checked
    if @params[:place]['public_status'] == '1'
      @place.public_status = Place::PUBLIC_STATUS_REQUESTED
    else
      @place.public_status = Place::PUBLIC_STATUS_NOT_REQUESTED
    end

    #KS- set the stuff from the post
    @place.name = @params[:place][:name]
    @place.location = @params[:place][:location]
    @place.phone = @params[:place][:phone]
    @place.url = @params[:place][:url]

    #KS- validate the location separately (we have to allow blank
    #locations outside of this method because of email plan
    #creation i think)
    @place.validate_location

    #KS- the place should always be private and owned by the current user
    @place.user_id = current_user.id
    @place.public = Place::PLACE_PRIVATE

    #KS- geocode the location
    @place.geocode_location!

    if @place.save && @place.errors.empty?
      flash[:notice] = 'Place was successfully edited.'
      if Place::PUBLIC_STATUS_REQUESTED == @place.public_status
        flash[:notice] += '<br/>Your new place will be publicly available when approved by a Skobee administrator.'
      end

      redirect_back_or_default url_for(:action => 'show', :id => @place.id)
    else
      render :action => 'edit'
    end
  end

  #KS- same as check read access but does not allow public places
  def check_write_access(ven)
    #KS- if it's a public venue raise an exception
    raise "Current user doesn't have rights to edit public place #{ven.id}" if ven.public_venue

    #KS- if it's owned by someone else, raise an exception
    raise "Current user doesn't have rights to edit place #{ven.id}" if ven.user_id != current_user.id
  end

  #KS- the bulk of this method's functionality is in check_read_access_helper. it was
  #pulled out to allow for easier testing
  def check_read_access(ven, plan_id = nil)
    usr = current_user
    check_read_access_helper(ven, plan_id, usr)
  end

  #KS- refactored this out for testing purposes
  def check_read_access_helper(ven, plan_id, usr)
    #MES- Is the place public?
    return ven if ven.public_venue
    
    #MES- If the usr is nil, they can't see private places.
    raise "You must log in to view this place" if usr.nil?
    
    #MES- We should be able to view public places,
    # places that we own, and places that are associated
    # with plans that we're attending.
    return ven if usr.administrator?


    #MES- Does the current user own the place?
    return ven if ven.owner == usr

    #MES- Is the place associated with the given plan, and is the current
    # user associated with the given plan?
    raise "Current user doesn't have read rights on place #{ven.id} and plan_id is nil" if plan_id.nil?

    pln = Plan.find(plan_id)
    raise "Current user doesn't have read rights on place #{ven.id} and plan #{plan_id} not found" if pln.nil?
    raise "Place #{ven.id} is not associated with plan #{plan_id}" if ven != pln.place
    if !pln.invitees.include? usr
      #MES- The user has to EITHER be on the plan OR be able to see a planner on which the plan is
      if params[:cal_id]
        planner = Planner.find(params[:cal_id])
        if !pln.planners.include?(planner)
          raise "Planner #{planner.id} does not include plan #{plan_id}"
        elsif planner.visibility_level(usr) < Planner::USER_VISIBILITY_LEVEL_DETAILS
          raise "Planner #{planner.id} not visible to current user"
        end
        return ven
      else
        #MGS- no planner passed on querystring
        raise "Current user is not associated with plan #{plan_id}"
      end
    end
    return ven
  end

  def find_places
    #MES- Set some defaults
    @days = DAY_ANY
    @timeperiod = Plan::TIME_DESCRIPTION_ALL_DAY
    @max_distance = DEFAULT_MAX_DISTANCE.to_s
    user = current_user
    if user.international?
      @home_address = ''
    else
      @home_address = user.zipcode
    end

    #KS- sidebar info
    #KS- places the current user has been recently
    @recent_places = Place.find_user_recent_places(user.id, 6)

    store_location

    #KS- places that are popular this week (by number of plans made there)
    @popular_this_week = Place.find_popular_by_day(current_user)
  end

  def search
    #MES- If the user indicated that the address is their home and/or work address, record it
    user = current_user
    store_location
    if !params['is_home'].nil? && !params['location'].nil?
      #MES- Store the location as the home address
      user.set_att(UserAttribute::ATT_ZIP, params['location'])
      @home_address = nil
    else
      #MES- Don't show the 'home address' for international users- it's bogus
      if user.international?
        @home_address = ''
      else
        @home_address = user.zipcode
      end
    end

    #KS- set the popular this week array for the sidebar
    @popular_this_week = Place.find_popular_by_day(current_user)

    #MES- Convert the parameters to member variables, for ease of processing
    hash_to_members(params, :days, :timeperiod, :fulltext, :location, :max_distance)

    #is time part of this search?
    #MES- Note that checking for time is not strictly necessary, since
    #  the user is forced to choose SOMETHING in the dropdowns, and we
    #  can pass that info to the search algorithm.
    time_set, day_array, timezone, begin_time, duration = false, nil, nil, nil, nil
    if !@days.nil? && !@timeperiod.nil? && ('-1' != @days || Plan::TIME_DESCRIPTION_ALL_DAY != @timeperiod.to_i)
      time_set = true
      if DAY_ANY == @days
        day_array = nil
      else
        day_array = @days.split(',')
        day_array.map! {|day| day.to_i}
      end
      timezone = TZInfo::Timezone.get(current_user.attributes['time_zone'])
      time_info = Plan::TIME_DESC_TO_TIME_MAP[@timeperiod.to_i]
      right_now = Time.now
      begin_time = Time.local(right_now.year, right_now.month, right_now.day, time_info[0], time_info[1])
      duration = time_info[2]
    else
      #MGS- just give the day/time periods a default value for ui rendering ease...
      @days = DAY_ANY
      @timeperiod = Plan::TIME_DESCRIPTION_ALL_DAY
    end

    #is proximity part of this search?  Location
    #and max_distance are always required
    where_set, bounding_box, max_distance = false, nil, nil
    if not_empty_or_nil(@location)
      where_set = true
      max_distance = @max_distance.to_i
      max_distance = DEFAULT_MAX_DISTANCE if max_distance <= 0
      bounding_box = GeocodeCacheEntry.get_bounding_box_array(@location, max_distance)
      if bounding_box.nil?
        #MES- The address was no good, tell the user so they can try again.
        flash.now[:error] = "Location #{@location} not understood.  Please enter a valid U.S. address."
        render :template => 'places/find_places'
        return
      end
    end

    #is text search part of this search?
    text_set, fulltext = false, nil
    if not_empty_or_nil(@fulltext)
      text_set = true
      fulltext = @fulltext
    end

    #MES- The text constraint must always be set (for performance- we
    # don't want to be returning tens of thousands of records)
    #MES- TODO: This USED to check that text OR location OR time was set.
    # When text isn't set, the result set is typically very large (e.g.
    # there are a LOT of businesses within 5 miles of a zipcode.)
    # These large result sets are expensive to process, so we don't allow it.
    # In the future, we may want to relax this, because the current
    # rules don't let you answer questions like "what restaurants are
    # popular on Saturday night?"
    if text_set
      @count = Place.count_by_name_prox_time(
        current_user,
        fulltext,
        bounding_box,
        max_distance,
        timezone,
        day_array,
        begin_time,
        duration,
        true)
      @results_per_page = 10
      @params['page'] = @params['page'].nil? ? 1 : @params['page']
      @place_pages = Paginator.new self, @count, @results_per_page, @params['page']
      @search_results = Place.find_by_name_prox_time(
        current_user,
        fulltext,
        bounding_box,
        max_distance,
        timezone,
        day_array,
        begin_time,
        duration,
        true,
        @place_pages.items_per_page,
        @place_pages.current.offset)
      render :template => 'places/find_places_results'
    else
      flash.now[:error] = "You must enter a 'what'"
      render :template => 'places/find_places'
    end
  end

  def report_error
    @place_id = params["id"]
    @report_url = params["report_url"]
  end

  def record_error
    report_url = params["report_url"]

    feedback = Feedback.new
    feedback.url = report_url
    feedback.user_id = current_user_id
    feedback.feedback_type = Feedback::FEEDBACK_TYPE_INACCURATE
    feedback.body = "ERROR in place #{params['id']}:\n#{params['body']}"
    feedback.stage = Feedback::FEEDBACK_STAGE_NEW
    feedback.save

    flash[:notice] = 'Error recorded.  Thank you for your feedback.'
    redirect_to_url report_url
  end

###############################################################
########  Helpers for comments
###############################################################

  def delete_comment_ajax
    #MGS- delete comment given place and comment ids
    place_id = params["place_id"]
    comment_id = params["comment_id"]

    comment = Comment.find(comment_id)
    @place = Place.find(place_id)
    comments = @place.comments
    comment.delete_from_collection(current_user, comments)

    render(:partial => "comments/comments", :object => comments)
  end

  def add_comment_ajax
    #MGS- delete comment given place and comment ids
    place_id = params["place_id"]
    comment_body = params["comment_tb"]

    @place = Place.find(place_id)
    comments = @place.comments
    #MGS- create comment, fill it with stuff, and save it
    comment = Comment.new()
    #MGS- TODO figure out if we want people to save empty comments
    comment.body = comment_body
    comment.owner_id = current_user_id
    if comment.save
      @place.comments << comment
    end
    #MGS- sort the returned collection
    render(:partial => "comments/comments", :object => @place.comments.sort)
  end

  def edit_comment_ajax
    #MGS- edit this comment
    comment_id = params["comment_id"]
    #MGS- this param is suffixed with the comment id for uniqueness
    comment_body_param = "comment_edit_tb" + comment_id
    comment_body = params[comment_body_param]
    place_id = params["place_id"]
    @place = Place.find(place_id)
    comment = Comment.find(comment_id)

    comment.body = comment_body
    if comment.update_attributes(params[:comment])
      #MGS- force a reload of the comments to get the updated collection
      render(:partial => "comments/comments", :object => @place.comments.reload)
    end
  end

  #MES- Returns the title of the section of the page that displays comments
  def comments_section_title
    'What are people saying?'
  end

  #MES- Returns the ID of the object that the comment refers to (i.e. the id
  # of the place that is being displayed.)
  def parent_of_comment_id
    @place.id
  end

  #MES- Returns the ID for the form element that will hold the identifier
  # of the item holding the comment
  def parent_of_comment_form_item
    'place_id'
  end

  #MGS- returns the number of comments to group at
  def comment_display_limit
    return 10
  end

  #MGS- should add comment access be allowed for this user viewing this page
  #	MES- True for authenticated users
  def check_add_comment_access
    return true if logged_in?
    return false
  end

  #MGS- returns the string to display when there are no comments
  def blank_comments_message
    return "Be the first to say something about this place."
  end

  def delete_comment?(comment)
    #MGS only allow creator to delete comments
    if current_user == comment.owner
      return true
    else
      return false
    end

  end
###############################################################
########  Set the static includes
###############################################################
  #MGS- sets the instance variable for js to include
  def set_static_includes
    @javascripts = [JS_SCRIPTACULOUS_SKOBEE_DEFAULT, JS_SKOBEE_COMMENTS]
  end

end
