class Place < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper

  has_and_belongs_to_many :comments, :order => "created_at DESC"
  #MES- When the owner is nil, it's a "public" place that all users can see.
  belongs_to :owner, :class_name => 'User'

  before_save :trim_name_whitespace!, :normalize_name!
  before_validation :normalize_phone!

  GEOCODE_NOT_GEOCODED = 0
  GEOCODE_GEOCODE_APPLIED = 1

  #MGS- public request status; currently only two
  PUBLIC_STATUS_NOT_REQUESTED = 0
  PUBLIC_STATUS_REQUESTED = 1

  PLACE_PRIVATE = 0
  PLACE_PUBLIC = 1

  #MES- Should geocoding be performed immediately when the location is changed?
  @@geocode_synchronously = false #MES- This COULD be a constant, but we want to test with it ON and with it OFF, so we make it a variable


  SQL_SECURITY_CONDITIONS = "(user_id = ? OR public = #{PLACE_PUBLIC})"
  SQL_SECURITY_CONDITIONS_TABLE_ALIAS = "(v.user_id = ? OR v.public = #{PLACE_PUBLIC})"

  SQL_PROXIMITY_BOUNDING_BOX =
    "places.lat < ? AND places.lat > ? AND places.long < ? AND places.long > ? AND (user_id = ? OR public = #{PLACE_PUBLIC})"

  SQL_HOUR_CLAUSE =
  'NOT (? > ((HOUR(e.start) * 60) + MINUTE(e.start) + e.duration) OR ? < ((HOUR(e.start) * 60) + MINUTE(e.start))) AND'

  MAX_HOURS_PLACE_STATS = 3 #MES- The maximum number of hours to track place stats per plan- if a plan spans more than this number of hours, there will only be entries for this number of hours


  POPULARITY_STATS_DAYS = 7 #MES- The number of days in the future to calculate popularity stats for
  POPULARITY_STATS_PLACES_PER_DAY = 500  #MES- The number of places which will be recorded as popular per day

  #KS- phone can be blank or 9 digits
  validates_format_of :phone, :with => /(^1?\d{10}$)|(^$)/, :message => "Phone number must be 9 digits long."

  #KS- there must be a name
  validates_presence_of :name

  #KS- address must be geocode-able
  def validate_location
    if GeocodeCacheEntry.find_loc(location).nil?
      errors.add(:location, 'you entered could not be found. You must enter a valid US address.')
    end
  end

  #KS- turn the tinyint in the database into a boolean
  def public_venue
    case public
      when 1
        return true
      else
        return false
    end
  end

  #MGS- has this place been requested to be promoted to public?
  def public_requested?
    return (self.public_status == PUBLIC_STATUS_REQUESTED) ? true : false
  end

  #KS- format the phone # for display
  def phone_formatted_for_display
    return number_to_phone(phone, {:area_code => true})
  end

  def location=(new_loc)
    #MES- Override the setter for location- we want to reset the geocoded flag, etc.
    # when the location changes.
    write_attribute('location', new_loc)
    write_attribute('geocoded', GEOCODE_NOT_GEOCODED)
    write_attribute('lat', nil)
    write_attribute('long', nil)
    #MES- If we're supposed to be geocoding "live", do that now
    if @@geocode_synchronously
      geocode_location!
    end
  end

  def location_is_physical_address?
    #MES- This function returns a boolean indicating if the
    # location field represents a physical address (as opposed
    # to an URL or similar.)  Used for mapping, etc.
    # In terms of implementation, Skobee assumes that a location is
    # a physical address if it has been successfully geocoded to a
    # lat and long.
    return !lat.nil? && !long.nil?
  end

  def geocode_location!
    #MES- Note: geocode_location!  DOES change the place object, but does NOT store the result
    # to the DB
#MES- TODO: Should we NOT geocode if the lat and long are already set?
    geocoded_info = GeocodeCacheEntry.find_loc(self.location)

    #MES- We want to indicate that geocoding was attempted, regardless of whether it was successful
    self.geocoded = GEOCODE_GEOCODE_APPLIED
    #MES- Did we find anything?  If we found MULTIPLE things, we'll
    # ignore this for now- we don't feel confident that we know which one
    # is the right one
    if !geocoded_info.nil?
      #MES- Record the lat and long
      copy_from(geocoded_info, :address, :city, :state, :zip, :lat, :long)
      return true
    else
      #MES- Failure, couldn't find unique hit
      logger.info "Place#geocode_location! failed to find a unique hit for #{location}"
      return false
    end
  end

  #KS- blow away any whitespace on the ends of the name
  def trim_name_whitespace!
    self.name.strip!
  end

  def normalize_name!
    #MES- Set the "normalized_name" field based on the name field.
    # It's basically the same, but lowercase and alphanumeric only.
    if name.nil?
      self.normalized_name = nil
    else
      self.normalized_name = Place.normalize_string(name)
    end
  end

  def self.normalize_string(string)
    #MES- Convert the string to a normalized form- lowercase, and stripped of punctuation
    return string.downcase.delete('^a-z0-9 ')
  end

  def normalize_phone!
    #MES- If the phone number is set, fix it up to be our normalized format.
    # The normalized format is basically all numbers (no dashes, parens, etc.)
    # and any leading '1's are stripped.
    # E.g. '1 (415) 399-2676' would be stored at '4153992676'

    if !self.phone.nil?
      #KS- only strip out dashes, spaces, parens, dots and leading 1s. all else leave in
      #so that it causes an explicit validation error
      phone_fixed = self.phone.delete('\-\ \(\).').match('(1)*(.*)')[2]
      
      #MES- Replace letters with digits.  Users can enter a phone number like 1-800-BUY-SOFT and
      # it'll translate to the proper digits.
      phone_fixed.gsub!(/[abc]/i, '2')
      phone_fixed.gsub!(/[def]/i, '3')
      phone_fixed.gsub!(/[ghi]/i, '4')
      phone_fixed.gsub!(/[jkl]/i, '5')
      phone_fixed.gsub!(/[mno]/i, '6')
      phone_fixed.gsub!(/[pqrs]/i, '7')
      phone_fixed.gsub!(/[tuv]/i, '8')
      phone_fixed.gsub!(/[wxyz]/i, '9')
      
      self.phone = phone_fixed
    end
  end

  def daily_stats
    #MES- Collect the daily statistics for the place- how many people are attending
    # per day
    sql = <<-END_OF_STRING
      SELECT
        day, sum(num_user_plans) AS total_user_plans
      FROM
        place_usage_stats
      WHERE
        place_id = ?
      GROUP BY
        day
    END_OF_STRING

    #MES- We'll make a hash that has the count for each day, and 0 for days with no count.
    # We will also add a max entry that is the maximum value we found
    result = Hash.new(0)
    rows = perform_select_all_sql([sql, id])
    max = 0
    if rows
      rows.each do | row |
        ct = row['total_user_plans'].to_i
        result[row['day'].to_i] = ct
        max = ct if ct > max
      end
    end
    result['max'] = max

    return result
  end



  def stat_date
    #MES- This is a hack.  The find_popular_by_day function selects the
    # info about the place, as well as the stat_date column from the
    # place_popularity_stats table.  Since ActiveRecord doesn't recognize
    # the column name (as it's not in the places table), it doesn't properly
    # convert the string to a date.  This would NORMALLY be done by
    # a combination of define_read_method in activerecord/base.rb and
    # type_cast_code in active_record/connection_adapters/abstract/schema_definitions.rb.
    # Since we can't use that, we just copy the code here.
    # TODO: Should we add a more generic function that wraps a member and does type
    # conversions?
    date_array = ParseDate.parsedate(@attributes['stat_date'])
    # treat 0000-00-00 as nil
    Date.new(date_array[0], date_array[1], date_array[2]) rescue nil
  end

  def popularity_rank
    #MES- See comment on stat_date
    (@attributes['pop_rank'].to_i rescue @attributes['pop_rank'] ? 1 : 0)
  end

  def popularity_count
    #MES- See comment on stat_date
    (@attributes['pop_count'].to_i rescue @attributes['pop_count'] ? 1 : 0)
  end

  #KS- return true if we think that this place is fully specified... basically
  #what i mean by this is do we think that not all the information for this venue
  #has been entered (and therefore it's more likely that the user actually means
  #something than what they have here but they were too lazy to specify it fully)
  def fully_specified
    !address.nil? && !address.empty? &&
    !city.nil? && !city.empty? &&
    !state.nil? && !state.empty? &&
    !zip.nil? && !zip.empty?
  end

  #KS- return true if we consider this place to have a fully specified location.
  #a fully specified location is one where we believe that the user does not
  #intend to input any further location information. i believe for the moment
  #that this means it either has an address, city, state, and zip OR a lat/long.
  def location_fully_specified
    (!address.nil? && !city.nil? && !state.nil? && !zip.nil?) || has_lat_long?
  end

  #KS- does this place have a lat/long?
  def has_lat_long?
    return !lat.nil? && !long.nil?
  end

###############################################################################
#MES- Class methods
###############################################################################

  #KS- get all the places from the plans where the user has status in or altered. this
  #is the place "touch list" and is used for the my recent places section in the place
  #search by name autocompleter
  def self.find_user_places(userid, max = 10)
    if userid.kind_of? User
      userid = userid.id
    end

    #KS- private places are included here!
    sql = <<-END_OF_STRING
        SELECT
          DISTINCT v.*
        FROM
          planners_plans as ce,
          #{Place.table_name} as v
        WHERE
            ce.user_id_cache = :user_id AND
          ce.cal_pln_status IN (:plan_statuses) AND
          ce.place_id_cache = v.id
        LIMIT :limit
      END_OF_STRING

    find_by_sql [sql, {:user_id => userid, :plan_statuses => Plan::STATUSES_ACCEPTED, :limit => max}]
  end

  #MES- Set the synchronous geocoding on changing a place address
  def self.geocode_synchronously=(val)
    @@geocode_synchronously = val
  end

  def self.find_recent_friend_places(userid, max = 10)
    #MES- We want to find the places that our friends have
    #  been to recently.
    #MES- NOTE: This SQL is somewhat heinous and may not perform
    #  well in large systems.  We may want to tune it, or precalculate
    #  this data through a daemon or similar.
    if userid.kind_of? User
      userid = userid.id
    end

    #MES- Note that we're only including public places here- users
    # cannot see the private places of other users.
    sql = <<-END_OF_STRING
      SELECT
        DISTINCT v.*
      FROM
        user_contacts as uc,
        planners_plans as ce,
        #{Place.table_name} as v
      WHERE
        uc.user_id = ? AND
        uc.friend_status = #{User::FRIEND_STATUS_FRIEND} AND
        uc.contact_id = ce.user_id_cache AND
        ce.cal_pln_status IN (?) AND
        ce.place_id_cache = v.id AND
        v.public = #{PLACE_PUBLIC}
      ORDER BY
        ce.plan_id DESC
      LIMIT ?
    END_OF_STRING

    self.find_by_sql [sql, userid, Plan::STATUSES_ACCEPTED, max]
  end

  def self.find_user_random_places(userid, max = 10)
    #KS- find any old random places a user has been to or is going to
    #MES- NOTE: This SQL is somewhat heinous and may not perform
    #  well in large systems.  We may want to tune it, or precalculate
    #  this data through a daemon or similar.
    if userid.kind_of? User
      userid = userid.id
    end

    #KS- do not include private places
    sql = <<-END_OF_STRING
        SELECT
          DISTINCT v.*
        FROM
          planners_plans as ce,
          #{Place.table_name} as v
        WHERE
          v.public = 1 AND
            ce.user_id_cache = ? AND
          ce.cal_pln_status IN (?) AND
          ce.place_id_cache = v.id
        ORDER BY
          RAND()
        LIMIT ?
      END_OF_STRING
    self.find_by_sql [sql, userid, Plan::STATUSES_ACCEPTED, max]
  end

  def self.find_user_recent_places(userid, max = 10)
    #MGS- We want to find the places we have been to recently
    #MES- NOTE: This SQL is somewhat heinous and may not perform
    #  well in large systems.  We may want to tune it, or precalculate
    #  this data through a daemon or similar.
    if userid.kind_of? User
      userid = userid.id
    end

    #MGS- we are including private places here
    sql = <<-END_OF_STRING
        SELECT
          DISTINCT v.*
        FROM
          #{Planner.table_name} as c,
          planners_plans as ce,
          #{Plan.table_name} as e,
          #{Place.table_name} as v
        WHERE
          #{SQL_SECURITY_CONDITIONS_TABLE_ALIAS} AND
            c.user_id = ? AND
          c.id = ce.planner_id AND
          ce.cal_pln_status IN (?) AND
          ce.plan_id = e.id AND
          e.start < ? AND
          e.place_id = v.id
        ORDER BY
          e.start DESC
        LIMIT ?
      END_OF_STRING
    self.find_by_sql [sql, userid, userid, Plan::STATUSES_ACCEPTED, Time.new, max]
  end

  #KS- find distinct popular places within the given date range. rank the results by the rank column in the
  #places popularity stats table (use the date as a tiebreaker)
  def self.find_popular_by_day(user = nil, date_begin = Time.now, date_end = (Time.now + 7.days), limit = 10)
    #MES- Find places that are considered popular for the given date range.
    # We'll constrain to places that are in the bounding box of the user,
    # to give relevant results.
    params = {:date_begin => date_begin.fmt_for_mysql(), :date_end => date_end.fmt_for_mysql(), :limit => limit}
    location_constraint = ''
    #MES- Do we have location info?
    if !user.nil? && !user.lat_max.nil? && !user.lat_min.nil? && !user.long_max.nil? && !user.long_min.nil?
      location_constraint = " AND plc.lat < :lat_max AND plc.lat > :lat_min AND plc.long < :long_max AND plc.long > :long_min"
      params[:lat_max] = user.lat_max
      params[:lat_min] = user.lat_min
      params[:long_max] = user.long_max
      params[:long_min] = user.long_min
    else
      #MES- The user isn't geocoded, so we don't know the metro.  We don't want to search ALL places,
      # for performance reasons, so we'll just look for places that aren't geocoded.
      location_constraint = " AND plc.lat IS NULL AND plc.long IS NULL"
    end

    sql = <<-END_OF_STRING
      SELECT
        plc.*, sum(pps.count)
      FROM
        places as plc,
        place_popularity_stats pps
      WHERE
        plc.id = pps.place_id AND
        plc.public = 1 AND
        pps.stat_date >= :date_begin AND
        pps.stat_date < :date_end#{location_constraint}
      GROUP BY
        #{Place.cols_for_select('plc')}
      ORDER BY
        sum(pps.count) DESC
      LIMIT :limit
    END_OF_STRING

    self.find_by_sql [sql, params]
  end

  def self.find_by_name_and_location_secure(name, location, user)
    #MES- Find the first place that the user should be able to see that
    # has the correct name

    #MES- Find places with the indicated name and/or location which are either public OR are private to userid
    # We want to include private places FIRST, so we'll order by the user_id (which will be
    # null for public places.)
    sql = '(' + SQL_SECURITY_CONDITIONS + ')'
    conds = [sql, user.id]
    if !name.nil?
      sql << ' AND name = ?'
      conds << name
    end
    if !location.nil?
      sql << ' AND location = ?'
      conds << location
    end
    #MES- Set metro info if it's available, AND we're not searching by location- if we're specifying
    # the location, it could be anywhere...
    if location.nil? && !user.lat_max.nil? && !user.lat_min.nil? && !user.long_max.nil? && !user.long_min.nil?
      sql << ' AND ((lat < ? AND lat > ? AND `long` < ? AND `long` > ?) OR lat IS NULL AND `long` IS NULL)'
      conds << user.lat_max
      conds << user.lat_min
      conds << user.long_max
      conds << user.long_min
    end
    return self.find(:first, :conditions => conds, :order => 'user_id DESC')
  end

  #MES- Find a place with the given name, or create it if not found.
  # Returns the place, and a boolean indicating if the item was created
  # (true) or found (false.)
  def self.find_or_create_by_name_and_location(name, location, user)
    #MES- Were we given nothing to search on?
    if name.nil? && location.nil?
      return [nil, false]
    end

    place = self.find_by_name_and_location_secure(name, location, user)
    return [place, false] if !place.nil?

    #MES- The place wasn't found, create a private place for the user
    place = Place.new(:name => name, :location => location, :user_id => user.id)
    place.save!
    return [place, true]
  end

  def self.find_by_ft_search(user, terms, include_private = false, limit = 10, offset = 0)
    return do_name_prox_time_query(false, user, terms, nil, nil, nil, nil, nil, nil, include_private, limit, offset)
  end

  #KS- find all the places that need to be geocoded (those that have geocoded
  #marked as GEOCODE_NOT_GEOCODED and have non-null, non-empty location strings
  def self.find_all_needing_geocoding
    find(:all, :conditions => [ "geocoded = ? AND location IS NOT NULL AND location != ''", GEOCODE_NOT_GEOCODED ])
  end

  #KS: finds the count for the find_by_name_prox_time method
  def self.count_by_name_prox_time(user, terms, location, max_distance, timezone, days, start_time, duration, include_private = false, limit = 1000, offset = 0)
    place_count_results = do_name_prox_time_query(true, user, terms, location, max_distance, timezone, days, start_time, duration, include_private, limit, offset)
    return place_count_results[0].ct.to_i
  end

  #full-on search encompassing fulltext name, proximity, and time
  def self.find_by_name_prox_time(user, terms, location, max_distance, timezone, days, start_time, duration, include_private = false, limit = 10, offset = 0)
    return do_name_prox_time_query(false, user, terms, location, max_distance, timezone, days, start_time, duration, include_private, limit, offset)
  end

  def self.find_for_autocomplete(user, terms, location = nil, max_distance = nil, limit = 10)
    #MES- Look for "word break" matches, ordered by number of times the user has been there
    res = find_word_break_match(user, terms, location, max_distance, limit, 0)
        #MES- If there were results, return them
    if !res.nil? && limit == res.length
      return res
    end

    #MES- We didn't get enough results, supplement our results with a "regular" search.
    #MES- TODO: Think about if this is a good idea.  These may be low quality hits, and
    # we're doing an extra SQL statement.
    supp_res = do_name_prox_time_query(false, user, terms, location, max_distance, nil, nil, nil, nil, true, limit, 0)

    #MES- add the "regular" items in, if they are not duplicates
    supp_res.each do | supp_item |
      res << supp_item if !res.include?(supp_item)
      break if limit <= res.length
    end

    return res
  end

  def self.find_word_break_match(user, terms, location = nil, max_distance = nil, limit = 10, offset = 0)
    #MES- This function is pretty similar to do_name_prox_time_query.  However, it
    # specifically matches the LEFT portion of the place name.  It's essentially
    # similar to "SELECT * FROM PLACES WHERE NORMALIZED_NAME LIKE '[terms]%'", but
    # should perform better.
    # This is intended to be used for things like autocomplete queries.
    # One twist is that we want to order by the number of times that the user has been
    # to the place.  But of course, the user may NOT have been to the place, so we
    # outer join to the planners_plans table to get the count of times, and order by that.
    sql_info = create_sql_info()

    #MES- Call the helper functions that know about each type of constraint
    add_user_sql_info(false, user, true, sql_info)
    add_proximity_sql_info(false, user, location, max_distance, sql_info)
    add_text_sql_info_word_break_match(terms, sql_info)
    add_limit_info(offset, limit, sql_info)

    sql_info[:group_by] << 'v.id'
    #MES- Here's a tricky bit- we're ordering by the sum of
    # pp.place_id_cache.  We want to order by the number of
    # rows in planners_plans (pp.)  But we're doing an outer
    # join, so there may be NO rows in pp that correspond to this
    # place.  We could do an "ORDER BY COUNT(*)", but I THINK that
    # would end up returning 1 in the case where there are no
    # matching rows in pp (since the OUTPUT- pre group-by- includes
    # a row.)  The sum of pp.place_id_cache will be zero when no
    # rows in pp match, and will increase linearly with the number
    # of matching rows in pp.
    sql_info[:order_by] << 'sum DESC'

    #MES- OK, time to put it together
    search_sql = <<-END_OF_STRING
      SELECT
        v.*, SUM(pp.place_id_cache) as sum
      FROM
        places AS v LEFT OUTER JOIN planners_plans AS pp ON v.id = pp.place_id_cache
      WHERE
        #{create_constraints_clause(sql_info)}#{create_group_by_clause(sql_info)}#{create_having_clause(sql_info)}#{create_order_by_clause(sql_info)}
      LIMIT :offset, :limit
    END_OF_STRING

    find_by_sql_with_params(search_sql, sql_info[:params])
  end

###############################################################################
#MES- Items used by/as agents
###############################################################################

  def self.perform_geocoding(max_freq_secs = 1, max_run_secs = 3600)
    start_time = Time.now()
    target_end = start_time + max_run_secs

    #MES- Find the items that need geocoding
    not_geocoded = find_all_needing_geocoding

    log_for_agent "In Place::perform_geocoding agent, attempting to geocode #{not_geocoded.length} places"
    num_geocoded = 0
    not_geocoded.each do | ven |
      target_item_end = Time.now() + max_freq_secs

      #MES- Do the geocoding
      logger.info "In Place::perform_geocoding- geocoding place #{ven.id}"
      ven.geocode_location!
      ven.save
      num_geocoded += 1

      #MES- Have we taken too much time?
      now = Time.now
      if now > target_end
        log_for_agent "Ran out of time in Place::perform_geocoding (geocoded #{num_geocoded} places in #{now - start_time} seconds)"
        return num_geocoded
      end

      #MES- Should we sleep a bit?  We don't want to hammer the server.
      sleep_secs = target_item_end.to_f - now.to_f
      sleep(sleep_secs) if sleep_secs > 0.0
    end

    #MES- We're done
    now = Time.now
    log_for_agent "Successfully geocoded in Place::perform_geocoding (geocoded #{num_geocoded} places in #{now - start_time} seconds)"
    return num_geocoded
  end

  def self.update_usage_stats
    log_for_agent "In Place::update_usage_stats agent, updating statistics"

    #MES- We want to refresh the place_usage_stats table.  Start by
    # clearing it out.
    perform_delete_sql('TRUNCATE TABLE place_usage_stats', 'Clearing the place_usage_stats table in preparation for updating statistics')

    #MES- Now add rows for each day/hour, counting the number of plans that happen then
    insert_rows_sql = <<-END_OF_STRING
      INSERT INTO place_usage_stats (place_id, day, hour, num_plans)
      SELECT
        v.id, MOD(DAYOFWEEK(e.local_start) - 1, 7) as day_wk, HOUR(e.local_start) as hr, count(*) as ct
      FROM
        places as v,
        plans as e
      WHERE
        v.id = e.place_id AND
        e.local_start IS NOT NULL AND
        (TO_DAYS(UTC_TIMESTAMP()) - TO_DAYS(e.local_start)) < 365
      GROUP BY
        v.id, day_wk, hr
    END_OF_STRING

    perform_insert_sql(insert_rows_sql, 'Adding rows to the place_usage_stats table')

    #MES- Now it gets a bit messy.  Plans may be longer than an hour, so we may need
    #  to add NEW rows to place_usage_stats for the plans we've already added, but
    #  at a different hour.
    #  Even more complicated, we may need to update EXISTING rows.  A place may have a
    #  three hour plan occurring in hour 5, and a one hour plan occurring in hour 6.
    #  We need to make the count for hour 6 have value 2, since there are essentially
    #  two concurrent plans happening in hour 6.  Hour 7 should have a count of 1, since
    #  the plan that started at 5 is still happening at hour 7

    #MES- We only do this logic for the first 3 hours- we don't handle plans that last more than
    # MAX_HOURS_PLACE_STATS hours
    1.upto(MAX_HOURS_PLACE_STATS) do | hour |

      #MES- We need to do the update first, so we don't update a row we just inserted
      update_for_hour_sql = <<-END_OF_STRING
        UPDATE place_usage_stats
        SET num_plans = num_plans +
          (
            SELECT count(*)
            FROM
              plans as e
            WHERE
              e.place_id = place_usage_stats.place_id AND
              MOD(DAYOFWEEK(e.local_start) - 1, 7) = place_usage_stats.day AND
              MOD(HOUR(e.local_start) + ?, 24) = place_usage_stats.hour AND
              e.duration >= ? AND
              (TO_DAYS(UTC_TIMESTAMP()) - TO_DAYS(e.local_start)) < 365
          )
      END_OF_STRING

      perform_update_sql([update_for_hour_sql, hour, 60*hour], "Updating rows for hour #{hour} in place_usage_stats table")

      #MES- Now insert the leftovers
      insert_for_hour_sql = <<-END_OF_STRING
        INSERT INTO place_usage_stats (place_id, day, hour, num_plans)
        SELECT
          v.id, MOD(DAYOFWEEK(e.local_start) - 1, 7) as day_wk, MOD(HOUR(e.local_start) + ?, 24) as hr, count(*) as ct
        FROM
          places as v,
          plans as e
        WHERE
          v.id = e.place_id AND
          e.local_start IS NOT NULL AND
          (TO_DAYS(UTC_TIMESTAMP()) - TO_DAYS(e.local_start)) < 365 AND
          e.duration >= ? AND
          NOT EXISTS
          (
            SELECT *
            FROM place_usage_stats
            WHERE
              place_id = v.id AND
              day = MOD(DAYOFWEEK(e.local_start) - 1, 7) AND
              hour = MOD(HOUR(e.local_start) + ?, 24)
          )
          GROUP BY
            v.id, day_wk, hr
      END_OF_STRING

      perform_insert_sql([insert_for_hour_sql, hour, 60*hour, hour], "Inserting rows for hour #{hour} in place_usage_stats table")

    end

    #MES- Then update the rows, to set the num_user_plans column
    0.upto(MAX_HOURS_PLACE_STATS) do | hour |
      update_user_pln_for_hour_sql = <<-END_OF_STRING
        UPDATE place_usage_stats
          SET num_user_plans = num_user_plans +
          (
            SELECT count(*)
            FROM
              plans as e,
              planners_plans as ce
            WHERE
              e.place_id = place_usage_stats.place_id AND
              e.id = ce.plan_id AND
              ce.cal_pln_status IN (?) AND
              MOD(DAYOFWEEK(e.local_start) - 1, 7) = place_usage_stats.day AND
              MOD(HOUR(e.local_start) + ?, 24) = place_usage_stats.hour AND
              e.duration >= ? AND
              (TO_DAYS(UTC_TIMESTAMP()) - TO_DAYS(e.local_start)) < 365
          )
      END_OF_STRING

      perform_update_sql([update_user_pln_for_hour_sql, Plan::STATUSES_ACCEPTED, hour, 60*hour], "Updating num_user_plans for hour #{hour} in place_usage_stats table")

    end

    log_for_agent "Successfully updated usage statistics in Place::update_usage_stats"
  end



  def self.update_popularity_stats
    #MES- Popularity stats are stored in the place_popularity_stats table.
    # Unlike usage stats, popularity stats are very transitory; they represent
    # a snapshot of what is popular at a given time.  They do NOT include all
    # places, or all times.
    log_for_agent "In Place::update_popularity_stats agent, updating statistics"

    insert_pop_stats_for_date = <<-END_OF_STRING
      INSERT INTO place_popularity_stats (stat_date, rank, count, place_id, lat, `long`)
      SELECT
        DATE(pln.local_start) AS pln_date, @pop_stats_rn := @pop_stats_rn + 1, count(*) AS rank, plc.id, plc.lat, plc.`long`
      FROM
        places AS plc,
        plans AS pln
      WHERE
        pln.place_id = plc.id AND
        DATE(pln.local_start) = ?
      GROUP BY
        pln_date, plc.id
      ORDER BY
        rank desc
      LIMIT ?
    END_OF_STRING


    #MES- Clear out any data- we want this table to be small
    perform_delete_sql('DELETE FROM place_popularity_stats')
    #MES- Add data for the next POPULARITY_STATS_DAYS days
    0.upto(POPULARITY_STATS_DAYS) do |day_offset |
      dt = Date.today + day_offset
      #MES- Use a variable to store the row number (MySQL doesn't support rownum per se, this is a workaround)
      perform_update_sql('SET @pop_stats_rn := 0')
      #MES- Insert the data for that day
      perform_insert_sql([insert_pop_stats_for_date, dt, POPULARITY_STATS_PLACES_PER_DAY])
    end
    log_for_agent "Successfully updated popularity statistics in Place::update_popularity_stats"
  end
  
  #MES- Update the yahoo_id column based on the yahoo_url column
  def self.update_yahoo_ids
    search_sql = <<-END_OF_STRING
      SELECT
        id, yahoo_url
      FROM
        places
      WHERE
        yahoo_url IS NOT NULL AND
        yahoo_id IS NULL
    END_OF_STRING
    
    update_sql = <<-END_OF_STRING
      UPDATE
        places
      SET
        yahoo_id = ?
      WHERE
        id = ?
    END_OF_STRING
    
    rows = perform_select_all_sql(search_sql)
    counter = 0
    rows.each do |row|
      skobee_id = row['id'].to_i
      yahoo_url = row['yahoo_url']
      m = yahoo_url.match(/[&?]id=([0-9]+)/)
      if !m.nil?
        yahoo_id = m[1].to_i
        perform_update_sql([update_sql, yahoo_id, skobee_id])
        #MES- Give some feedback once in a while
        putc '.' if (0 == (counter & 0xff))
        counter += 1
      end
    end
  end


###############################################################################
#MES- Internal helpers
###############################################################################

private

  def self.do_name_prox_time_query(perform_count, user, terms, location, max_distance, timezone, days, start_time, duration, include_private, limit, offset)
    #MES- We want to compartmentalize the logic to add SQL for each case (proximity search,
    # full text search, and time search.)  We create individual functions that know about the
    # details of each of these kinds of searches.  They all add their info (WHERE clause constraints,
    # group by clauses, etc.) to this hash of info.  Then this function puts it all together.
    sql_info = create_sql_info()

    if perform_count
      sql_info[:select_items] << 'COUNT(DISTINCT v.id) as ct'
    else
      sql_info[:select_items] << 'v.*'
    end

    #MES- Call the helper functions that know about each type of constraint
    add_user_sql_info(perform_count, user, include_private, sql_info)
    add_time_sql_info(perform_count, timezone, days, start_time, duration, sql_info)
    add_proximity_sql_info(perform_count, user, location, max_distance, sql_info)
    add_text_sql_info(perform_count, terms, sql_info)
    add_limit_info(offset, limit, sql_info)

    #MES- OK, time to put it together
    search_sql = <<-END_OF_STRING
      SELECT
        #{sql_info[:select_items].join(', ')}
      FROM
        #{sql_info[:tables].join(', ')}
      WHERE
        #{create_constraints_clause(sql_info)}#{create_group_by_clause(sql_info)}#{create_order_by_clause(sql_info)}
      LIMIT :offset, :limit
    END_OF_STRING

    return find_by_sql_with_params(search_sql, sql_info[:params])
  end

  def self.create_sql_info
    #MES- Return a "sql_info" structure that subsequent code will modify, etc.
    return {
      :select_items => [],
      :tables => ["#{Place.table_name} as v"],
      :constraints => [],
      :group_by => [],
      :order_by => [],
      :having => [],
      :params => [{}]
    }
  end

  def self.find_by_sql_with_params(sql, params)
    #MES- Add the SQL to the front of the array of params.
    # NOTE: We should NOT do a flatten, since some of the
    # individual params may be arrays.
    params.unshift(sql)
    results = find_by_sql(params)
    return results
  end

  def self.create_constraints_clause(sql_info)
    return sql_info[:constraints].join(' AND ')
  end

  def self.create_group_by_clause(sql_info)
    return sql_info[:group_by].empty? ? '' : ("\n GROUP BY " + sql_info[:group_by].join(', '))
  end

  def self.create_order_by_clause(sql_info)
    return sql_info[:order_by].empty? ? '' : ("\n ORDER BY " + sql_info[:order_by].join(', '))
  end

  def self.create_having_clause(sql_info)
    return sql_info[:having].empty? ? '' : ("\n HAVING " + sql_info[:having].join(', '))
  end

  def self.add_user_sql_info(perform_count, user, include_private, sql_info)
    if !include_private
      #MES- Only show public places
      sql_info[:constraints] << "v.public = #{PLACE_PUBLIC}"
    else
      #MES- We know the User, show their places, AND public places
      sql_info[:constraints] << "(v.user_id = :user_id OR v.public = #{PLACE_PUBLIC})"
      sql_info[:params][0][:user_id] = user.id
    end
  end

  def self.add_time_sql_info(perform_count, timezone, days, start_time, duration, sql_info)
    #MES- Only add the timezone stuff if they specified the relevant information
    if !timezone.nil? && (!days.nil? || (!start_time.nil? && !duration.nil?))
      #MES- If we're not doing a "perform_count" (that is, just counting the number of items that
      # match) we should add a COUNT of plans to the select clause, so that we can order by it.
      if (!perform_count)
        sql_info[:select_items] << 'count(*) as plan_ct'
      end

      #MES- To filter on time, we need to join in the Plans table.
      # It needs to be in the FROM clause
      sql_info[:tables] << "place_usage_stats as vus"
      #MES- And in the WHERE clause
      sql_info[:constraints] << 'v.id = vus.place_id'

      #MES- Filter on the day of week
      if !days.nil?
        sql_info[:constraints] << 'vus.day IN(:days)'
        sql_info[:params][0][:days] = days
      end

      #MES- Delegate dealing with hours to a helper.
      add_hours_sql_info(perform_count, timezone, start_time, duration, sql_info)

      #MES- If we not just counting rows, group by the place values and order by
      # the count of plans
      if !perform_count
        #MES- Group by the place columns so that the count(*) works right
        sql_info[:group_by] << "#{Place.cols_for_select('v')}"
        #MES- Sort by the count descending
        sql_info[:order_by] << "vus.num_plans DESC"
      end
    end
  end

  def self.add_hours_sql_info(perform_count, timezone, start_time, duration, sql_info)
    #MES- Did the user specify "all day" or a particular time of day?
    if !start_time.nil? && !duration.nil? && duration != (23*60 + 59) #MES- 23*60 + 59 minutes means "all day" to us
      #MES- The user specified a particular time of day, figure out how that would be
      # represented in the DB.

      #MES- What is the first hour of interest
      first_hour = start_time.hour
      #MES- How many hours should we consider?  Duration is in minutes, convert to hours
      num_hours = duration / 60
      num_hours = MAX_HOURS_PLACE_STATS if num_hours > MAX_HOURS_PLACE_STATS
      hours = []
      num_hours.downto(0) do | hour_offset |
        hours << (first_hour + hour_offset) % 24
      end

      #MES- Add the time constraint
      sql_info[:constraints] << 'vus.hour IN (:hours)'
      sql_info[:params][0][:hours] = hours
    end
  end

  def self.add_proximity_sql_info(perform_count, user, location, max_distance, sql_info)
    #MES- Only add the proximity info if the user supplied a distance or a bounding box
    bounding_box = nil
    explicit_location_constraint = false
    if !max_distance.nil? || (!location.nil? && location.is_a?(Array))
      #MES- If location is an array with 4 items, then we have a bounding box (in lat/long),
      # so just use that.  If location is a string, we have to geocode it to get the bounding
      # box
      explicit_location_constraint = true #MES- They're explicitly constraining on location
      if location.is_a? String
        #MES- Get the lat/long bounding box
        bounding_box = GeocodeCacheEntry.get_bounding_box_array(location, max_distance)
      elsif location.is_a? Array
        bounding_box = location
      else
        #MES- Don't know what this is!
        raise "Error in Place::add_proximity_sql_info, location must be a string or an array, but is of type #{location.class.name}."
      end
    end

    #MES- If we didn't get a bounding box based on the location argument,
    # we want to add a bounding box from the user (this is the "metros" feature.)
    if bounding_box.nil? && (!user.lat_max.nil? && !user.lat_min.nil? && !user.long_max.nil? && !user.long_min.nil?)
      bounding_box = [user.lat_max, user.lat_min, user.long_max, user.long_min]
    end


    #MES- Did we get legit data?
    # NOTE: It's OK to not have a good bounding box- perhaps no data was explicitly
    # supplied, and we don't know anything about the location of the user.
    if !bounding_box.nil? && 4 == bounding_box.length
      #MES- Add the SQL clause
      #MES- If they're explicitly constraining on location, do NOT look for places that are not geocoded
      if explicit_location_constraint
        sql_info[:constraints] << 'v.lat < :lat_max AND v.lat > :lat_min AND v.long < :long_max AND v.long > :long_min'
      else
        sql_info[:constraints] << '((v.lat < :lat_max AND v.lat > :lat_min AND v.long < :long_max AND v.long > :long_min) OR (v.lat IS NULL AND v.long IS NULL) OR v.user_id = :bb_user_id)'
      sql_info[:params][0][:bb_user_id] = user.id
      end
      #MES- And the params
      sql_info[:params][0][:lat_max] = bounding_box[0]
      sql_info[:params][0][:lat_min] = bounding_box[1]
      sql_info[:params][0][:long_max] = bounding_box[2]
      sql_info[:params][0][:long_min] = bounding_box[3]
    else
      #MES- The user doesn't have a metro.  They should still be able to see places that
      # either are NOT geocoded or are owned by that user.
      sql_info[:constraints] << '((v.lat IS NULL AND v.long IS NULL) OR v.user_id = :bb_user_id)'
      sql_info[:params][0][:bb_user_id] = user.id
    end
  end

  def self.add_text_sql_info(perform_count, terms, sql_info)
    #MES- Only add the full text terms if the terms were supplied
    if !terms.nil? && terms != ''
      if !perform_count
        #KS- select the relevance
        sql_info[:select_items] << 'MATCH(v.normalized_name) AGAINST (:search_terms) as relevance'
        #KS- order by relevance
        sql_info[:order_by].insert(0, 'relevance DESC')
      end
      #MES- Matching text is easy, just add the clause and the param
      sql_info[:constraints] << 'MATCH(v.normalized_name) AGAINST (:search_terms)'
      #MES- Normalize the search terms- lowercase, remove punctuation
      search_terms = normalize_string(terms)
      sql_info[:params][0][:search_terms] = search_terms
    end
  end

  def self.add_limit_info(offset, limit, sql_info)
    sql_info[:params][0][:offset] = offset
    sql_info[:params][0][:limit] = limit
  end

  def self.add_text_sql_info_word_break_match(terms, sql_info)
    #MES- This is similar to add_text_info, but instead of doing a
    # "full text" type query, it does a "word break match" type query
    # (conceptually similar to "XXX like '[terms]%' OR XXX like '% [terms]%'"

    #MES- We're doing a little MySQL hackery here.  We want the SQL to end up something like:
    #
    # select
    #   *, MATCH (normalized_name) AGAINST ('+hotel +b*' IN BOOLEAN MODE)
    # from
    #   places
    # where
    #   MATCH (normalized_name) AGAINST ('+hotel +b*' IN BOOLEAN MODE)
    # having
    #   (normalized_name like 'hotel b%' OR normalized_name like '% hotel b%'
    #
    #This should act just like a LIKE clause, but NOT do a full table scan


    #MES- Only add the text terms if the terms were supplied
    if !terms.nil? && terms != ''
      #MES- Matching text is easy, just add the clause and the param
      sql_info[:constraints] << 'MATCH(v.normalized_name) AGAINST (:search_terms IN BOOLEAN MODE)'
      #MES- Normalize the search terms- lowercase, remove punctuation, and add the MySQL query operators
      cleaned_terms = normalize_string(terms)

      search_terms = '+' + cleaned_terms.split.join(' +') + '*'
      sql_info[:params][0][:search_terms] = search_terms

      sql_info[:having] << "(v.normalized_name LIKE :having_terms OR v.normalized_name LIKE :mid_having_terms)"
      sql_info[:params][0][:having_terms] = cleaned_terms + '%'
      sql_info[:params][0][:mid_having_terms] = '% ' + cleaned_terms + '%'
    end
  end

end
