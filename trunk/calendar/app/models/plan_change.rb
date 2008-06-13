  class PlanChange < ActiveRecord::Base

  #MES- A PlanChange object encompasses changes that have been applied to a plan.
  # The change may be a comment, a change of place (with an optional comment), or
  # a change of time (with an optional comment)

  belongs_to :owner, :class_name => 'User', :foreign_key => 'owner_id'
  belongs_to :plan
  before_save :truncate_comment!, :override_time_if_needed!

  CHANGE_TYPE_COMMENT = 0 #MES- The change is JUST a comment- the object is not altered
  CHANGE_TYPE_PLACE = 1
  CHANGE_TYPE_TIME = 2
  CHANGE_TYPE_PLACE_COMMENT = 3
  CHANGE_TYPE_TIME_COMMENT = 4
  CHANGE_TYPE_RSVP = 5  #MES- The RSVP status for a user on the plan was changed

  CHANGE_TYPES_COMMENTS = [CHANGE_TYPE_COMMENT, CHANGE_TYPE_PLACE_COMMENT, CHANGE_TYPE_TIME_COMMENT]
  
  #MES- An awkward name, but this array is all change types that are comments OR "real" changes to the plan
  # NOTE: This does NOT include RSVP status changes
  CHANGE_TYPES_COMMENTS_AND_CHANGES = [CHANGE_TYPE_COMMENT, CHANGE_TYPE_PLACE_COMMENT, CHANGE_TYPE_TIME_COMMENT, CHANGE_TYPE_PLACE, CHANGE_TYPE_TIME]
  
  #MES- Constants that can be used to access the items in the array
  # returned by initial_time and final_time
  TIME_CHANGE_START_INDEX = 0
  TIME_CHANGE_TIMEPERIOD_INDEX = 1
  TIME_CHANGE_FUZZY_START_INDEX = 2
  TIME_CHANGE_DURATION_INDEX = 3

  #MES- Returns the created_at or updated_at time, as appropriate for sorting this
  # type of change
  def sort_time
    #MES- We want to sort place and time changes by their created_at time, since we don't
    # really care when the comment was changed.  For comment changes, we want to sort by
    # the updated_at time, since that time reflects when the relevant content was created.
    return self.updated_at if CHANGE_TYPES_COMMENTS.member?(self.change_type)

    return self.created_at
  end

  #MES- Returns a boolean indicating if this change is a comment.
  def comment?
    return CHANGE_TYPES_COMMENTS.member?(self.change_type)
  end

  #MGS- Returns a boolean indicating if this change is related to places
  def is_place_related?
    return [CHANGE_TYPE_PLACE, CHANGE_TYPE_PLACE_COMMENT].member?(self.change_type)
  end

  #MGS- Returns a boolean indicating if this change is related to times
  def is_time_related?
    return [CHANGE_TYPE_TIME, CHANGE_TYPE_TIME_COMMENT].member?(self.change_type)
  end


  ############################################################################
  # MES- Helpers related to place changes
  ############################################################################

  #MES- Record that the place for the plan changed
  def place_changed(user, old_place, new_place, time_of_change = nil)
    self.change_type = CHANGE_TYPE_PLACE
    self.owner = user
    self.initial_value = (old_place.nil? ? nil : old_place.id)
    self.final_value = (new_place.nil? ? nil : new_place.id)
    @override_time_of_change = time_of_change
    return self
  end

  #MES- Return the initial place for the change
  def initial_place
    if CHANGE_TYPE_PLACE != self.change_type
      raise "Error in PlanChange#initial_place, the change_type is #{self.change_type}, but is expected to be #{CHANGE_TYPE_PLACE}"
    end

    #MGS- comments can be stored for a particular type
    # so a comment may be stored as a CHANGE_TYPE_PLACE, but with no initial/final value
    if self.initial_value.nil?
      return nil
    end

    Place.find(self.initial_value.to_i)
  end

  #MES- Return the final place for the change
  def final_place
    if CHANGE_TYPE_PLACE != self.change_type
      raise "Error in PlanChange#final_place, the change_type is #{self.change_type}, but is expected to be #{CHANGE_TYPE_PLACE}"
    end

    #MGS- comments can be stored for a particular type
    # so a comment may be stored as a CHANGE_TYPE_PLACE, but with no initial/final value
    if self.final_value.nil?
      return nil
    end

    Place.find(self.final_value.to_i)
  end


  ############################################################################
  # MES- Helpers related to time changes
  ############################################################################

  #MES- Record that the time for the plan changed
  def time_changed(user, old_start, old_timeperiod, old_fuzzy_start, old_duration, new_start, new_timeperiod, new_fuzzy_start, new_duration, time_of_change = nil)
    self.change_type = CHANGE_TYPE_TIME
    self.owner = user
    #MES- We store the times as integers (seconds since epoch), separated by semicolons
    self.initial_value = old_start.nil? ? "0;0;0;0" : "#{old_start.to_i};#{old_timeperiod};#{old_fuzzy_start.to_i};#{old_duration}"
    self.final_value = "#{new_start.to_i};#{new_timeperiod};#{new_fuzzy_start.to_i};#{new_duration}"
    @override_time_of_change = time_of_change
    return self
  end

  #MES- Return the initial time for the change.  The return format is
  # an array containing [start, timeperiod, fuzzy_start, duration].  The indices
  # in this array are described by the TIME_CHANGE_*_INDEX constants
  def initial_time
    if CHANGE_TYPE_TIME != self.change_type
      raise "Error in PlanChange#initial_time, the change_type is #{self.change_type}, but is expected to be #{CHANGE_TYPE_TIME}"
    end

    #MGS- comments can be stored for a particular type
    # so a comment may be stored as a CHANGE_TYPE_TIME, but with no initial/final value
    if self.initial_value.nil?
      return nil
    end

    #MES- See comment in time_changed for info on format
    times = self.initial_value.split(';')
    return Time.at(times[0].to_i).utc, times[1].to_i, Time.at(times[2].to_i).utc, times[3].to_i
  end

  #MES- Return the final time for the change.  The return format is
  # an array containing [start, timeperiod, fuzzy_start, duration].  The indices
  # in this array are described by the TIME_CHANGE_*_INDEX constants
  def final_time
    if CHANGE_TYPE_TIME != self.change_type
      raise "Error in PlanChange#final_time, the change_type is #{self.change_type}, but is expected to be #{CHANGE_TYPE_TIME}"
    end

    #MGS- comments can be stored for a particular type
    # so a comment may be stored as a CHANGE_TYPE_TIME, but with no initial/final value
    if self.final_value.nil?
      return nil
    end

    #MES- See comment in time_changed for info on format
    times = self.final_value.split(';')
    return Time.at(times[0].to_i).utc, times[1].to_i, Time.at(times[2].to_i).utc, times[3].to_i
  end


  ############################################################################
  # MES- Helpers related to RSVP changes
  ############################################################################

  def rsvp_changed(user, old_status, new_status)
    self.change_type = CHANGE_TYPE_RSVP
    self.owner = user
    #MES- Just store the old and new statuses
    self.initial_value = old_status
    self.final_value = new_status
    return self
  end

  def initial_rsvp_status
    if CHANGE_TYPE_RSVP != self.change_type
      raise "Error in PlanChange#initial_rsvp_status, the change_type is #{self.change_type}, but is expected to be #{CHANGE_TYPE_RSVP}"
    end

    return self.initial_value.to_i
  end

  def final_rsvp_status
    if CHANGE_TYPE_RSVP != self.change_type
      raise "Error in PlanChange#final_rsvp_status, the change_type is #{self.change_type}, but is expected to be #{CHANGE_TYPE_RSVP}"
    end

    return self.final_value.to_i
  end

  def final_rsvp_status_name
    #MGS- adding helper to return the name of the status; will return the status if it exists
    # in the Plan:STATUS_NAMES collection, otherwise returns a blank string;  returning a blank
    # string is useful because there are some statuses we don't want to display
    if CHANGE_TYPE_RSVP != self.change_type
      raise "Error in PlanChange#final_rsvp_status_name, the change_type is #{self.change_type}, but is expected to be #{CHANGE_TYPE_RSVP}"
    end

    return Plan::STATUS_NAMES[self.final_value.to_i]
  end

  #MGS- deletes the change and reference on parent object (ie plan/place)
  def delete_from_collection(usr, coll)
    if check_security(usr)
      coll.delete self
      self.destroy
    end
  end

  #MGS- check to make sure current user is the owner of change
  def check_security(usr)
    raise "Wrong user to edit/delete change (was #{usr.id} but should be #{owner.id})!" if usr != owner
    return true
  end

  def truncate_comment!
    #MGS- we want to silently handle the case where the user enters more text than we can handle for the body (like flickr)
    # only saving the first 4096 characters.
    if !self.comment.nil?
      self.comment.slice!(4096..-1)
    end
  end

  def override_time_if_needed!
    #MES- Sometimes, we want to set the created_at to be earlier than now.  We do this here.
    # We'd want to do this if the PlanChange object reflects a change that happened in the
    # past. Specifically, if the PlanChange is meant to represent the "original" state of
    # a plan, we want the created_at date of the PlanChange to match the created_at date
    # of the plan to which this applies.
    if @override_time_of_change
      self.created_at = @override_time_of_change
    end
  end


  #MES- Find recent PlanChanges for the indicated user that are related to
  # plans for which the user has status ACCEPTED or INTERESTED.  The results
  # are sorted in the default manner.
  def self.find_recent(user_id, exclude_user = true, limit = 5, offset = 0)
    #MES- This is intended to be used to show a snapshot of what's been
    # changing for the user.  We'd like to show only alterations that have
    # happened since the user last looked at the plan which was changed, but
    # we don't currently have a good way to know which alterations have
    # happened AFTER the user viewed the plan.  Therefore, we'll just show
    # the most recent changes
    #MGS- adding new exclude_user option, which defaults to true;  this only displays
    # plan changes that are not from the user_id;  user doesn't want to see
    # his own changes...only everyone else's.

    if user_id.is_a?(User)
      user_id = user_id.id
    end

    sql = <<-END_OF_STRING
      SELECT
        pc.*
      FROM
        #{PlanChange.table_name} as pc,
        #{Plan.table_name} as p,
        planners_plans as pp
      WHERE
        pc.plan_id = pp.plan_id AND
        p.id = pc.plan_id AND
        pp.user_id_cache = :user_id AND
        pc.owner_id != :exclude_user_id AND
        pp.cal_pln_status IN (:statuses_accepted) AND
        p.fuzzy_start >= UTC_TIMESTAMP()
      ORDER BY
        pc.created_at desc
      LIMIT :offset, :limit
    END_OF_STRING

    #MGS- if we are excluding add the user_id as an extra argument, otherwise empty string is passed in
    exclude_user_id = exclude_user ? user_id : ""
    res = self.find_by_sql [sql, {:user_id => user_id, :exclude_user_id => exclude_user_id, :statuses_accepted => Plan::STATUSES_ACCEPTED, :offset => offset, :limit => limit}]
    return res.sort
  end

  #MGS- Find recent PlanChanges for the indicated user.  We don't care about
  # the user's current status on the plan. The results are sorted in
  # the default manner.
  def self.find_recent_for_user(user_id, limit = 20, offset = 0)
    if user_id.is_a?(User)
      user_id = user_id.id
    end

    sql = <<-END_OF_STRING
      SELECT
        DISTINCT pc.*
      FROM
        #{PlanChange.table_name} as pc,
        #{Plan.table_name} as p
      WHERE
        p.id = pc.plan_id AND
        p.security_level = #{Plan::SECURITY_LEVEL_PUBLIC} AND
        pc.owner_id = ?
      ORDER BY
        pc.created_at desc
      LIMIT ?, ?
    END_OF_STRING

    res = self.find_by_sql [sql, user_id, offset, limit]
    return res.sort
  end

  #MGS- Return plan changes from your friends and/or contacts.  Takes an array of friend
  # statuses to query for.  This does not take into account that these user's accept
  # statuses on the plan like PlanChanges.find_recent() does.  This query is extra complicated
  # as we need to respect planner level security when querying for the changes.  If the planner
  # is PUBLIC, then we can show all plan changes.  If the planner is set to PRIVACY_LEVEL_FRIENDS,
  # we need to perform an additional sub-select to ensure that the inverse friend relationship is
  # there.
  def self.find_contact_recent_changes(user_id, friend_statuses, limit = 20, offset = 0)
    if user_id.is_a?(User)
      user_id = user_id.id
    end

    sql = <<-END_OF_STRING
      SELECT DISTINCT
        pc.*
      FROM
        #{PlanChange.table_name} as pc,
        #{Plan.table_name} as p
      WHERE
        p.id = pc.plan_id AND
        p.security_level = #{Plan::SECURITY_LEVEL_PUBLIC} AND
        pc.owner_id IN (
                        SELECT
                          contact_id
                        FROM
                          user_contacts as uc,
                          planners as p
                        WHERE
                          p.user_id = uc.contact_id AND
                          p.visibility_type = #{SkobeeConstants::PRIVACY_LEVEL_PUBLIC} AND
                          uc.friend_status IN (:statuses) AND
                          uc.user_id = :user_id
                    UNION
                        SELECT
                          contact_id
                        FROM
                          user_contacts as uc,
                          planners as p
                        WHERE
                          p.user_id = uc.contact_id AND
                          p.visibility_type = #{SkobeeConstants::PRIVACY_LEVEL_FRIENDS} AND
                          uc.friend_status IN (:statuses) AND
                          uc.user_id = :user_id AND
                          EXISTS (
                              SELECT
                                *
                              FROM
                                user_contacts uc2
                              WHERE
                                uc2.friend_status = #{User::FRIEND_STATUS_FRIEND} AND
                                uc2.contact_id = :user_id AND
                                uc2.user_id = uc.contact_id
                           )
      )
      ORDER BY
        pc.created_at desc
      LIMIT :offset, :limit
    END_OF_STRING

    res = self.find_by_sql [sql, {:user_id => user_id, :statuses => friend_statuses, :offset => offset, :limit => limit}]
    return res.sort
  end

  #MES- Define the default sort
  def <=>(other)
    #MES- Sort by sort_time, if they're different
    st = self.sort_time <=> other.sort_time
    return (-1 * st) if 0 != st #MES- -1 for descending

    #MES- They're the same, sort by id
    return -1 * (self.id <=> other.id) #MES- -1 for descending
  end

end
