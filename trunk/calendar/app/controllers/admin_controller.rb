require 'yahoo_api'

class AdminController < ApplicationController
  include YahooAPI

  before_filter :login_required, :set_static_includes, :admin_login_required

  def admin_login_required
    if !current_user.administrator?
      logger.error "NON Administrative user #{current_user_id} attempted to view action #{@action} in the Admin controller"
      #MES- They're not administrator, they got here by accident (or maliciousness!)
      #MES- TODO: Should we show a standard 404 error here?  That might be slightly more secure.
      redirect_back
      return false
    end
  end

  def stats
    #MES- TODO: Could we do fewer DB round trips by putting many of these together as UNIONs?
    @num_sessions = execute_count_sql("SELECT COUNT(*) AS CT FROM sessions")
    @num_users = execute_count_sql("SELECT COUNT(*) AS CT FROM users")
    @num_registered_users = execute_count_sql("SELECT COUNT(*) AS CT FROM users WHERE salted_password != ''")
    @num_users_added_by_existing_members = execute_count_sql("SELECT COUNT(*) AS CT FROM users WHERE generation_num > 0")
    @avg_plans_per_user = execute_float_sql("SELECT AVG(CT) AS FT FROM (SELECT COUNT(*) AS CT FROM planners_plans GROUP BY user_id_cache) AS SUB")
    @num_contacts = execute_count_sql("SELECT COUNT(*) AS CT FROM user_contacts")
    @avg_contacts_per_user = @num_contacts.to_f / @num_users.to_f
    @num_contacts_checked = execute_count_sql("SELECT COUNT(*) AS CT FROM user_contacts WHERE clipboard_status = 2")
    @avg_checked_contacts_per_user = @num_contacts_checked.to_f / @num_users.to_f
    @num_users_not_notified_on_plan_mod = execute_count_sql("SELECT COUNT(*) AS CT FROM user_atts WHERE att_id = #{UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION} AND att_value = #{UserAttribute::PLAN_MODIFIED_NEVER}")
    @num_users_not_notified_on_invite = execute_count_sql("SELECT COUNT(*) AS CT FROM user_atts WHERE att_id = #{UserAttribute::ATT_INVITE_NOTIFICATION_OPTION} AND att_value = #{UserAttribute::INVITE_NOTIFICATION_NEVER}")

    @num_plans = execute_count_sql("SELECT COUNT(*) AS CT FROM plans")
    @num_plans_in_public_places = execute_count_sql("SELECT COUNT(*) AS CT FROM plans, places WHERE plans.place_id = places.id AND places.public = 1")
    @num_fuzzy_plans = execute_count_sql("SELECT COUNT(*) AS CT FROM plans WHERE start != fuzzy_start")
    @num_not_fuzzy_plans = @num_plans - @num_fuzzy_plans

    @num_plans_in_private_places = execute_count_sql("SELECT COUNT(*) AS CT FROM plans, places WHERE plans.place_id = places.id AND places.public = 0")
    @avg_users_per_plan = execute_float_sql("SELECT AVG(CT) AS FT FROM (SELECT plans.id, COUNT(*) as CT FROM plans, planners_plans WHERE plans.id = planners_plans.plan_id GROUP BY plans.id) AS all_data")
    plans_with_range_of_users_prototype = "SELECT COUNT(*) AS CT FROM plans WHERE (SELECT COUNT(*) FROM planners_plans WHERE plans.id = planners_plans.plan_id) BETWEEN %d AND %d"
    @num_plans_with_1_or_2_users = execute_count_sql(sprintf(plans_with_range_of_users_prototype, 1, 2))
    plans_with_num_users_prototype = "SELECT COUNT(*) AS CT FROM plans WHERE %d = (SELECT COUNT(*) FROM planners_plans WHERE plans.id = planners_plans.plan_id)"
    @num_plans_with_3_users = execute_count_sql(sprintf(plans_with_num_users_prototype, 3))
    @num_plans_with_4_users = execute_count_sql(sprintf(plans_with_num_users_prototype, 4))
    @num_plans_with_5_users = execute_count_sql(sprintf(plans_with_num_users_prototype, 5))
    @num_plans_with_6_users = execute_count_sql(sprintf(plans_with_num_users_prototype, 6))
    @num_plans_with_7_to_10_users = execute_count_sql(sprintf(plans_with_num_users_prototype, 7, 10))
    @num_plans_with_11_to_20_users = execute_count_sql(sprintf(plans_with_num_users_prototype, 11, 20))
    @num_plans_with_more_than_20_users = execute_count_sql("SELECT COUNT(*) AS CT FROM plans WHERE 20 < (SELECT COUNT(*) FROM planners_plans WHERE plans.id = planners_plans.plan_id)")
    plans_with_duration_prototype = "SELECT COUNT(*) AS CT FROM plans WHERE duration = %d"
    @num_all_day_plans = execute_count_sql(sprintf(plans_with_duration_prototype, Plan::TIME_DESC_TO_TIME_MAP[Plan::TIME_DESCRIPTION_ALL_DAY][2]))
    @num_eve_plans = execute_count_sql(sprintf(plans_with_duration_prototype, Plan::TIME_DESC_TO_TIME_MAP[Plan::TIME_DESCRIPTION_EVENING][2]))
    @num_dinner_afternoon_plans = execute_count_sql(sprintf(plans_with_duration_prototype, Plan::TIME_DESC_TO_TIME_MAP[Plan::TIME_DESCRIPTION_DINNER][2]))
    @num_lunch_bfst_plans = execute_count_sql(sprintf(plans_with_duration_prototype, Plan::TIME_DESC_TO_TIME_MAP[Plan::TIME_DESCRIPTION_LUNCH][2]))
    @num_morning_plans = execute_count_sql(sprintf(plans_with_duration_prototype, Plan::TIME_DESC_TO_TIME_MAP[Plan::TIME_DESCRIPTION_MORNING][2]))
    @num_other_time_plans = execute_count_sql("SELECT COUNT(*) AS CT FROM plans WHERE duration NOT IN (#{Plan::TIME_DESC_TO_TIME_MAP[Plan::TIME_DESCRIPTION_ALL_DAY][2]}, #{Plan::TIME_DESC_TO_TIME_MAP[Plan::TIME_DESCRIPTION_EVENING][2]}, #{Plan::TIME_DESC_TO_TIME_MAP[Plan::TIME_DESCRIPTION_DINNER][2]}, #{Plan::TIME_DESC_TO_TIME_MAP[Plan::TIME_DESCRIPTION_LUNCH][2]}, #{Plan::TIME_DESC_TO_TIME_MAP[Plan::TIME_DESCRIPTION_MORNING][2]})")

    users_of_age_prototype = "SELECT COUNT(*) AS CT FROM user_atts WHERE att_id = #{UserAttribute::ATT_BIRTH_YEAR} AND group_id = #{UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP} AND att_value <= (EXTRACT(YEAR FROM UTC_DATE()) - %d) AND att_value >= (EXTRACT(YEAR FROM UTC_DATE()) - %d)"
    @users_0_to_14 = execute_count_sql(sprintf(users_of_age_prototype, 0, 14))
    @users_15_to_18 = execute_count_sql(sprintf(users_of_age_prototype, 15, 18))
    @users_19_to_22 = execute_count_sql(sprintf(users_of_age_prototype, 19, 22))
    @users_23_to_27 = execute_count_sql(sprintf(users_of_age_prototype, 23, 27))
    @users_28_to_35 = execute_count_sql(sprintf(users_of_age_prototype, 28, 35))
    @users_36_to_49 = execute_count_sql(sprintf(users_of_age_prototype, 36, 49))
    @users_50_to_64 = execute_count_sql(sprintf(users_of_age_prototype, 50, 64))
    @users_65_to_200 = execute_count_sql(sprintf(users_of_age_prototype, 65, 200))

    @users_no_age = execute_count_sql("SELECT COUNT(*) AS CT FROM user_atts WHERE att_id = #{UserAttribute::ATT_BIRTH_YEAR} AND group_id = #{UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP} AND att_value = '' OR att_value IS NULL")
    @users_no_age += execute_count_sql("SELECT COUNT(*) AS CT FROM users WHERE NOT EXISTS (SELECT * FROM user_atts WHERE users.id = user_atts.user_id AND user_atts.att_id = #{UserAttribute::ATT_BIRTH_YEAR} AND user_atts.group_id = #{UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP})")

    #MES- TODO: We could do this in one SQL statement with a GROUP BY
    users_of_gender_prototype = "SELECT COUNT(*) AS CT FROM user_atts WHERE att_id = #{UserAttribute::ATT_GENDER} AND group_id = #{UserAttribute::ATT_GENDER_SECURITY_GROUP} AND att_value = '%d'"
    @male_users = execute_count_sql(sprintf(users_of_gender_prototype, UserAttribute::GENDER_MALE))
    @female_users = execute_count_sql(sprintf(users_of_gender_prototype, UserAttribute::GENDER_FEMALE))
    @gender_unknown_users = execute_count_sql(sprintf(users_of_gender_prototype, UserAttribute::GENDER_UNKNOWN))
    @no_gender_users = execute_count_sql("SELECT COUNT(*) AS CT FROM users WHERE NOT EXISTS (SELECT * FROM user_atts WHERE users.id = user_atts.user_id AND user_atts.att_id = #{UserAttribute::ATT_GENDER} AND user_atts.group_id = #{UserAttribute::ATT_GENDER_SECURITY_GROUP})")

    users_of_relationship_prototype = "SELECT COUNT(*) AS CT FROM user_atts WHERE att_id = #{UserAttribute::ATT_RELATIONSHIP_STATUS} AND group_id = #{UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP} AND att_value = '%d'"
    @single_users = execute_count_sql(sprintf(users_of_relationship_prototype, UserAttribute::RELATIONSHIP_TYPE_SINGLE))
    @taken_users = execute_count_sql(sprintf(users_of_relationship_prototype, UserAttribute::RELATIONSHIP_TYPE_TAKEN))
    @relationship_unknown_users = execute_count_sql(sprintf(users_of_relationship_prototype, UserAttribute::RELATIONSHIP_TYPE_UNKNOWN))
    @relationship_no_data_users = execute_count_sql("SELECT COUNT(*) AS CT FROM users WHERE NOT EXISTS (SELECT * FROM user_atts WHERE users.id = user_atts.user_id AND user_atts.att_id = #{UserAttribute::ATT_RELATIONSHIP_STATUS} AND user_atts.group_id = #{UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP})")

    @zip_1_data = User.perform_select_all_sql("SELECT att_value DIV 10000 as zip_1, COUNT(*) AS CT FROM user_atts WHERE att_id = #{UserAttribute::ATT_ZIP} AND group_id = #{UserAttribute::ATT_ZIP_SECURITY_GROUP} AND att_value != '#{User::INTL_USER_ZIPCODE_STR}' GROUP BY zip_1")
    @intl_users = execute_count_sql("SELECT COUNT(*) AS CT FROM user_atts WHERE att_id = #{UserAttribute::ATT_ZIP} AND group_id = #{UserAttribute::ATT_ZIP_SECURITY_GROUP} AND att_value = '#{User::INTL_USER_ZIPCODE_STR}'")
    @no_zip_users = execute_count_sql("SELECT COUNT(*) AS CT FROM users WHERE NOT EXISTS (SELECT * FROM user_atts WHERE users.id = user_atts.user_id AND user_atts.att_id = #{UserAttribute::ATT_ZIP} AND user_atts.group_id = #{UserAttribute::ATT_ZIP_SECURITY_GROUP})")
  end


  #MES- Impersonate the indicated user
  def impersonate
    logger.info "Administrative user #{current_user_id} is attempting to impersonate user #{@params['user']}"
    @user = User.find(@params['user'])
    set_session_user(@user)
    render :text => "Successfully impersonated #{@user.login}"
  end

###############################################################
########  Administrative Actions For Places
###############################################################

  def approve_places
    #@places_pages, @places = paginate(:places, :constraints => [:public_status == Place::PUBLIC_STATUS_REQUESTED], :per_page => 10)

    @places_pages = Paginator.new self, Place.count, 200, @params['page']
    @places = Place.find :all, :conditions => "public_status = #{Place::PUBLIC_STATUS_REQUESTED}",
                         :limit  =>  @places_pages.items_per_page,
                         :offset =>  @places_pages.current.offset
  end

  #MES- Approve the places as public
  def do_approve_places
    places = 0
    #MES- Iterate through the places
    iterate_posted_places do | place |
      #MES- Make it public
      place.public = Place::PLACE_PUBLIC
      #MGS- make sure we set the status back
      place.public_status = Place::PUBLIC_STATUS_NOT_REQUESTED
      #KS- geocode it
      place.geocode_location!
      place.save
      places += 1
    end
    flash[:notice] = "#{places} places approved"
    redirect_to :action => 'approve_places'
  end

  #MES- Reject the places for public viewing
  def do_reject_places
    places = 0
    #MES- Iterate through the places
    iterate_posted_places do | place |
      #MES- Reject each one.  Right now, this just means changing their
      # status such that the request to be public is turned off.  NOT TOO COOL.
      place.public_status = Place::PUBLIC_STATUS_NOT_REQUESTED
      place.save
      places += 1
    end
    flash[:notice] = "#{places} places rejected"
    redirect_to :action => 'approve_places'
  end

  #MES- Iterate over the places that were posted by approve_places
  def iterate_posted_places
    #MES- Look for params that look like place_[place id]
    params.each do | param_id, param_value |
      m = param_id.match(/place_(\d*)/)
      if !m.nil?
        place = Place.find(m[1])
        yield place
      end
    end
  end

  def edit_place
    @yahoo_local_search = []
    @similar_places_in_skobee = []
    @similar_places_in_skobee_by_location = []

    @places = Place.find(params[:id])
    #MGS- perform a full-text search for places with this name
    @similar_places_in_skobee = Place.find_by_ft_search(current_user, @places.name, false, 25)
    #MGS- if the current place is returned in the results, remove it from the array
    @similar_places_in_skobee.delete(@places)

    #MGS- perform a search by location for places like this within 50 miles
    bounding_box = GeocodeCacheEntry.get_bounding_box_array(@places.location, 50)
    @similar_places_in_skobee_by_location = []
    if !bounding_box.nil?
      @similar_places_in_skobee_by_location = Place.find_word_break_match(current_user, @places.name, bounding_box, 25)
    end
    #MGS- if the current place is returned in the results, remove it from the array
    @similar_places_in_skobee_by_location.delete(@places)

    #MGS- perform a a yahoo local search for results
    if @places.zip.nil?
      @yahoo_location_searched = @places.location
      @yahoo_local_search = simple_local_search(@places.name, @places.location)
    else
      @yahoo_location_searched = @places.zip
      @yahoo_local_search = simple_local_search(@places.name, '', @places.zip)
    end
  end

  def update_place
    @place = Place.find(params[:id])
    if @place.update_attributes(params[:places])

      if @place.public == Place::PLACE_PUBLIC
        #MGS- make sure we set the status back
        @place.public_status = Place::PUBLIC_STATUS_NOT_REQUESTED

        #KS- geocode it
        @place.geocode_location!

        @place.save
      end

      flash[:notice] = 'Place was successfully updated.'
      redirect_to :controller => 'places', :action => 'show', :id => @place
    else
      render :action => 'edit_place'
    end
  end


  ###############################################################
  ########  Set the static includes
  ###############################################################
  #MGS- sets the instance variable for js to include
  def set_static_includes
    @javascripts = [JS_SCRIPTACULOUS_SKOBEE_DEFAULT]
  end

  private

  #MES- Execute SQL that returns a count (in column alias 'CT')
  def execute_count_sql(sql)
    #MES- Perform the SQL and return the CT column from the first row
    User.perform_select_all_sql(sql)[0]['CT'].to_i
  end

  #MES- Execute SQL that returns a float (in column alias 'CT')
  def execute_float_sql(sql)
    #MES- Perform the SQL and return the CT column from the first row
    User.perform_select_all_sql(sql)[0]['FT'].to_f
  end
end
