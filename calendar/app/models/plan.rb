class Plan < ActiveRecord::Base
  has_and_belongs_to_many :planners
  has_many :plan_changes, :class_name => 'PlanChange', :dependent => true, :order => 'id DESC'
  belongs_to :place
  has_many :email_ids, :exclusively_dependent => true

  after_save :after_save_handler
  before_save :truncate_description

  #MES- Should we make a distinction between a blocking invite (e.g. from
  #  a friend) and a nonblocking invite (e.g. from a business)?
  STATUS_INVITED = 1    #MES- The user has been invited to this plan, but has not yet accepted or rejected
  STATUS_ACCEPTED = 2   #MES- The user has accepted an invitation to this plan
  STATUS_REJECTED = 3    #MES- The user has rejected an invitation to this plan
#MES- STATUS_ALTERED IS DEPRECATED
#  STATUS_ALTERED = 4    #MES- The user has accepted an invitation to this plan, but the invitation was subsequently altered, so it's not clear that the user still accepts
  STATUS_CANCELLED = 5  #MGS- This plan has been cancelled.
  STATUS_INTERESTED = 6 #MES- The user is interested in this plan.  This is functionally similar (or identical) to STATUS_ACCEPTED, but is less of a commitment from the user
  STATUS_NO_RELATION = 99  #MES- The user is no longer on the invite list for this plan (the user MAY have previously been on the invite list)

  STATUS_NAMES = {
    STATUS_INVITED => "I'm Invited",
    STATUS_ACCEPTED => "I'll Be There",
    STATUS_REJECTED => "I'm Out",
    STATUS_INTERESTED => "I'm Interested",
  }

  #MES- All statuses that mean "I've accepted"
  STATUSES_ACCEPTED = [STATUS_ACCEPTED, STATUS_INTERESTED]

  #MES- All statuses that mean "I've rejected"
  STATUSES_REJECTED = [STATUS_REJECTED]

  #MES- All statuses that indicate that the user has responded
  STATUSES_RESPONDED = [STATUS_ACCEPTED, STATUS_REJECTED]

  #MES- All statuses that indicate that the user has responded or been
  # invited (i.e. NOT statuses like STATUS_CANCELLED or STATUS_NO_RELATION)
  STATUSES_INVOLVED = [STATUS_INVITED, STATUS_ACCEPTED, STATUS_REJECTED, STATUS_INTERESTED]

  #MES- All statuses that indicate that the user has accepted OR was invited
  STATUSES_ACCEPTED_OR_INVITED = [STATUS_INVITED, STATUS_ACCEPTED, STATUS_INTERESTED]

  #MES- Ownership statuses for a plan
  OWNERSHIP_INVITEE = 0
  OWNERSHIP_OWNER = 1

  #MES- Security levels for a plan
  SECURITY_LEVEL_PUBLIC = 0     #MES- World visible (subject to planner constraints)
  SECURITY_LEVEL_PRIVATE = 1    #MES- Only attendees and invitees can see anything about the plan
  OTHER_SECURITY = {
    SECURITY_LEVEL_PUBLIC => SECURITY_LEVEL_PRIVATE,
    SECURITY_LEVEL_PRIVATE => SECURITY_LEVEL_PUBLIC
  }
  
  #MES- Lock statuses for a plan
  LOCK_STATUS_UNLOCKED = 0      #MES- The plan is not locked at all
  LOCK_STATUS_OWNERS_ONLY = 1   #MES- Only owners of the plan may alter it
  #MES- We might want a LOCK_STATUS_LOCKED which means that NOBODY can alter it (without first unlocking it.)
  OTHER_LOCK = {
    LOCK_STATUS_UNLOCKED => LOCK_STATUS_OWNERS_ONLY,
    LOCK_STATUS_OWNERS_ONLY => LOCK_STATUS_UNLOCKED
  }

  TIME_DESCRIPTION_CUSTOM = 0
  TIME_DESCRIPTION_ALL_DAY = 1
  TIME_DESCRIPTION_EVENING = 2
  TIME_DESCRIPTION_DINNER = 3
  TIME_DESCRIPTION_AFTERNOON = 4
  TIME_DESCRIPTION_LUNCH = 5
  TIME_DESCRIPTION_MORNING = 6
  TIME_DESCRIPTION_BREAKFAST = 7
  TIME_DESCRIPTION_NOT_SET = 8
  TIME_DESCRIPTION_INVALID = 9

  TIME_DESC_TO_TIME_MAP = {
    TIME_DESCRIPTION_ALL_DAY => [0, 0, (23*60 + 59)],
    TIME_DESCRIPTION_EVENING => [19, 0, (4*60 + 58)],
    TIME_DESCRIPTION_DINNER => [18, 0, (3*60 + 30)],
    TIME_DESCRIPTION_AFTERNOON => [14, 0, (3*60 + 30)],
    TIME_DESCRIPTION_LUNCH => [12, 0, (60 + 30)],
    TIME_DESCRIPTION_MORNING => [9, 0, (2*60 + 30)],
    TIME_DESCRIPTION_BREAKFAST => [7, 0, (60 + 30)],
  }.freeze

  TIME_DESC_TO_ENGLISH = [
    [TIME_DESCRIPTION_ALL_DAY, 'All Day'],
    [TIME_DESCRIPTION_EVENING, 'Evening'],
    [TIME_DESCRIPTION_DINNER, 'Dinner'],
    [TIME_DESCRIPTION_AFTERNOON, 'Afternoon'],
    [TIME_DESCRIPTION_LUNCH, 'Lunch'],
    [TIME_DESCRIPTION_MORNING, 'Morning'],
    [TIME_DESCRIPTION_BREAKFAST, 'Breakfast'],
  ].freeze
  TIME_DESC_TO_ENGLISH_MAP = TIME_DESC_TO_ENGLISH.to_hash

  HOUR_DESCRIPTIONS = [ 12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 ].freeze
  MINUTE_DESCRIPTIONS = [ 0, 15, 30, 45 ].freeze
  MERIDIAN_DESCRIPTIONS = [ "AM", "PM" ].freeze

  DATE_DESCRIPTION_CUSTOM = 0
  DATE_DESCRIPTION_TODAY = 1
  DATE_DESCRIPTION_TOMORROW = 2
  DATE_DESCRIPTION_YESTERDAY = 3
  DATE_DESCRIPTION_THIS_WEEKEND = 4
  DATE_DESCRIPTION_NEXT_WEEKEND = 5
  DATE_DESCRIPTION_THIS_WEEK = 6
  DATE_DESCRIPTION_NEXT_WEEK = 7
  DATE_DESCRIPTION_LAST_WEEK = 8
  DATE_DESCRIPTION_THIS_MONTH = 9
  DATE_DESCRIPTION_NEXT_MONTH = 10
  DATE_DESCRIPTION_LAST_MONTH = 11
  DATE_DESCRIPTION_FUTURE = 12
  DATE_DESCRIPTION_INVALID = 13

  DATE_DESCRIPTIONS = {
    DATE_DESCRIPTION_TODAY => 'Today',
    DATE_DESCRIPTION_TOMORROW => 'Tomorrow',
    DATE_DESCRIPTION_YESTERDAY => 'Yesterday',
    DATE_DESCRIPTION_THIS_WEEKEND => 'Some day this Weekend',
    DATE_DESCRIPTION_NEXT_WEEKEND => 'Some day next Weekend',
    DATE_DESCRIPTION_THIS_WEEK => 'Some day this Week',
    DATE_DESCRIPTION_NEXT_WEEK => 'Some day next Week',
    DATE_DESCRIPTION_LAST_WEEK => 'Last Week',
    DATE_DESCRIPTION_THIS_MONTH => 'This Month',
    DATE_DESCRIPTION_NEXT_MONTH => 'Next Month',
    DATE_DESCRIPTION_LAST_MONTH => 'Last Month',
    DATE_DESCRIPTION_FUTURE => 'Some day in the Future'
  }.freeze

  #MGS- default future date; we will hardcode the startdate to this day if
  FUZZY_FUTURE_DATE = Date.civil(2030, 1, 1)

  #MGS- default date/time settings for plans
  DEFAULT_DATE = DATE_DESCRIPTION_FUTURE
  DEFAULT_TIME = TIME_DESCRIPTION_ALL_DAY
  
  #MES- Plans that occurred more than 6 hours in the past are considered "past"
  #	for the purposes of display.  We do NOT want to consider plans that are only
  #	10 minutes in the past to be past (e.g. if you're having lunch at noon, you still
  #	might want to cancel the plan at 12:10.  But by 7 PM that day, cancelling the plan
  #	doesn't really make sense.
  PLAN_PAST_SECS = 60 * 60 * 6


  #MES- When looking up latest plans, we don't want to consider ALL plans,
  # so we only look at those that are within the fudge factor of the
  # highest plan ID.  There may be NO plans within this number that are
  # actually visible, so we don't want this number to be too small.  On
  # the other hand, the performance of the query seems to scale with
  # this number, so we don't want it to be too big (without the constraint,
  # a query on a system with 1,000,000 plans takes like 30 seconds or more.)
  LATEST_PLANS_ID_FUDGE_FACTOR = 100

  def initialize(attributes = nil)
    super
    #MGS- default the duration of any plan to two hours
    # this can be overridden by specific fuzzy time durations
    self.duration = 120
    @revert_info = nil

    #MES- Set the default security
    @security_level = Plan::SECURITY_LEVEL_PUBLIC
    @security_changed = false
  end

  def security_level=(val)
    #MES- We want to capture the "on change" event, so we know to
    #  fix up caches that record this value on save
    @attributes['security_level'] = val
    @security_changed = true
  end

  def owner
    owner_planner = planners.detect {|cal| !cal.attributes['ownership'].nil? && cal.ownership.to_i == OWNERSHIP_OWNER}
    owner_planner.nil? ? nil : owner_planner.owner
  end

  #KS- convenience method that fetches the name of the associated place, if there
  #is one
  def place_name
    if !place_id.nil?
      place = Place.find(place_id)
      if !place.nil? && !place.name.nil? && !place.name.empty?
        return place.name
      end
    end
    nil
  end

  def display_name
    return name ? name : '[no name]'
  end

  def confirmed_invitees_other_than(usr)
    return invitees(STATUSES_RESPONDED, usr)
  end

  def all_invitees_other_than(usr)
    return invitees(STATUSES_INVOLVED, usr)
  end

  def attending_invitees_other_than(usr)
    return invitees(STATUSES_ACCEPTED, usr)
  end

  def invitees(statuses = nil, excludes = nil)
    excludes = excludes.id if excludes.kind_of? User

    #MES- Returns the list of users invited to this plan with the given status

#MES- TODO: Turn this into a helper function on some base class, like Object?  Or use to_ary?
    if statuses.nil?
      statuses = STATUSES_INVOLVED
    elsif statuses.kind_of? Numeric
      statuses = [statuses]
    end

    if excludes.nil?
      excludes = []
    elsif excludes.kind_of? Numeric
      excludes = [excludes]
    end

    #MES- Run through the planners for this plan, finding the items that match
    #  our search criteria
    result = []
#MES- TODO: This code causes 2 SQL statements per planner- one to get the
# planner, and another to get the user.  I'm not quite sure why Rails
# is opening the planner object via a unique SQL statement (it seems like
# it should be able to get all planners for a given plan in a single SQL
# statement.)
# This could possibly be avoided by caching the user login in the planners_plans
# table.
    self.planners.each do | cal |
      if statuses.include? cal.cal_pln_status.to_i then
        usr = cal.owner
        if !excludes.include? usr.id then
          result << usr
        end
      end
    end

    result
  end
  
  def can_edit?(plnr)
    #MES- Were we passed nil?
    return false if plnr.nil?
    
    #MES- Get the info about this plan for the planner
    pln_info = nil
    begin
      pln_info = self.planners.find(plnr.id)
    rescue ActiveRecord::RecordNotFound
      #MES- Ignore a "planner not found" error- if the planner isn't on the plan, then we'll leave pln_info nil
    end
    return false if pln_info.nil?
    
    is_owner = (OWNERSHIP_OWNER == pln_info.ownership.to_i)
    
    #MES- If the user has NOT accepted the plan and they are NOT the owner, they cannot edit it
    return false if (!Plan::STATUSES_ACCEPTED.member?(pln_info.cal_pln_status.to_i) && !is_owner)
    
    #MES- If the plan is locked AND the user is NOT an owner of the plan, they cannot edit it
    return false if (LOCK_STATUS_UNLOCKED != self.lock_status && !is_owner)
    
    #MES- They passed all the tests, they can edit it
    return true
  end
  
  #MES- Is the indicated planner an owner of the plan
  def is_owner?(plnr)
    #MES- Were we passed nil?
    return false if plnr.nil?
    
    #MES- Get the info about this plan for the planner
    pln_info = nil
    begin
      pln_info = self.planners.find(plnr.id)
    rescue ActiveRecord::RecordNotFound
      #MES- Ignore a "planner not found" error- if the planner isn't on the plan, then we'll leave pln_info nil
    end
    return false if pln_info.nil?
    
    return OWNERSHIP_OWNER == pln_info.ownership.to_i
  end
  
  #MES- An array of the flickr IDs for users attending the plan
  def flickr_ids
    res = []
    self.invitees(STATUSES_ACCEPTED).each do | usr |
        flickr_id = usr.get_att_value(UserAttribute::ATT_FLICKR_ID)
        res << flickr_id if !flickr_id.nil?
    end
    
    return res
  end
  
  #MES- Could this plan have photos?
  def could_have_photos?
    #MES- If the plan hasn't happened yet, it can only have photos if
    # it has flickr tags.
    if !self.occurs_in_past?
      return !self.flickr_tags.blank? && !(self.flickr_ids.empty?)
    else
      #MES- The plan is in the past- if there are any users associated
      #  with flickr IDs, then the plan could have photos
      return !(self.flickr_ids.empty?)
    end
  end
  
  #MES- Returns an array of flickr photo info for the plan.
  #  Each entry is an array like [url to thumbnail, url to display photo in Flickr]
  def flickr_photos_info(timezone, max_photos = 10)
    flickr = Flickr.new(FLICKR_API_KEY)
    photonames = self.flickr_ids
#MES- TODO: For testing, using the smedberg@gmail.com Flickr user, and a fuzzy start of 2006-02-26 shows photos of my Hawaiian vacation.
    tz = timezone.nil? ? User::DEFAULT_TIME_ZONE_OBJ : timezone
    date_local = tz.utc_to_local(self.fuzzy_start)
    date_start_string = date_local.fmt_date_for_mysql
    date_end_string = (date_local + 24 * 60 * 60).fmt_date_for_mysql
    photos_found = 0
    in_past = self.occurs_in_past?
    photo_info = []
    photonames.each do |pname|
      begin
        user = flickr.users(pname)
      rescue RuntimeError => e
        #MES- Ignore the error- the library throws when a user isn't found
      end
      if !user.nil?
        photos = []
        #MES- First, see if any of the users have photos that match the tags
        if !self.flickr_tags.blank?
          #MES- If there are no photos, the flickr library fails
          begin
            photos = photos + flickr.photos_fixed({:user_id => user.id, :tags => self.flickr_tags, :per_page => max_photos.to_s, :tag_mode => 'all'})
            #user.tag(self.flickr_tags)
          rescue Exception => e
            #MES- Ignore the error- the library can't handle empty lists
          end
        end
        #MES- Second, see if there are any photos for the time of the plan (which only happens if the plan is in the past)
        if in_past
          #MES- Note: it seems like the dates are midnight to midnight, so if you want photos taken on the 25th, you'd set the
          # min to 25th and the max to the 26th
          #MES- If there are no photos, the flickr library fails
          begin
            photos = photos + flickr.photos_fixed({:user_id => user.id, :min_taken_date => date_start_string, :max_taken_date => date_end_string, :per_page => max_photos.to_s})
          rescue Exception => e
            #MES- Ignore the error- the library can't handle empty lists
          end
        end
        photos.each do | photo |
          #MES- Note, the click-through URL is to the Large image.  When I tried the Medium, it
          # uses "Michael Smedberg" as my Flickr username, but should use "smedberg".  This appears
          # to be a bug in Flickr, rather than in the Ruby library- the Flickr API is returning
          # "Michael Smedberg" for username, but expects "smedberg" in URLs
          thumb, large = nil, nil
          sizes = photo.sizes
          #MES- Is there a thumbnail?
          thumb = sizes.find{|asize| asize['label'] == 'Thumbnail'}
          if !thumb.nil?
            #MES- Look for a larger size
            large = sizes.find{|asize| asize['label'] == 'Original'}
            large = sizes.find{|asize| asize['label'] == 'Large'} if large.nil?
            large = sizes.find{|asize| asize['label'] == 'Medium'} if large.nil?
            large = thumb if large.nil?
          end
          
          photo_info << [thumb['source'], large['url']]
          
          photos_found += 1
          
          #MES- Did we find all the photos we need?
          break if photos_found >= max_photos
        end
        
        #MES- Did we find all the photos we need?
        break if photos_found >= max_photos
      end
    end

    return photo_info
  end


  #MES- Some helper functions related to the status of an individual plan
  # NOTE: Since the status info is stored in the planners_plans table (NOT
  # in plans), status info is only available if you got to the plan through
  # a planner.plans collection.  Calling these methods on a "straight-up"
  # plan will cause errors.
  def accepted?
    return STATUSES_ACCEPTED.member?(self.cal_pln_status.to_i)
  end

  def rejected?
    return STATUSES_REJECTED.member?(self.cal_pln_status.to_i)
  end

  def responded?
    return STATUSES_RESPONDED.member?(self.cal_pln_status.to_i)
  end

  def involved?
    return STATUSES_INVOLVED.member?(self.cal_pln_status.to_i)
  end

  def cancelled?
    return STATUS_CANCELLED == self.cal_pln_status.to_i
  end

  def is_expiring?(timezone)
    #MGS- is this plan a fuzzy plan whose details have not been set?
    if self.start == self.fuzzy_start
      #MGS- only fuzzy plans can expire
      return false
    end
    #MGS- tomorrow is now plus one day in seconds
    tomorrow = timezone.now + (60 * 60 * 24)
    local_fuzzy_start = timezone.utc_to_local(self.fuzzy_start)
    #MGS- if the fuzzy start time is on the next calendar day, this plan is expiring
    # only compare the dates
    if local_fuzzy_start.to_date <= tomorrow.to_date
      return true
    end
    return false
  end

  def fuzzy?(timezone)
    #MGS- is this plan a fuzzy plan; helps a lot in the UI if we can easily get this
    if ((self.start != self.fuzzy_start) || (self.dateperiod(timezone) == DATE_DESCRIPTION_FUTURE))
      return true
    else
      return false
    end
  end
  
  #MES- Does this plan occur in the past?
  def occurs_in_past?
  	#MES- Note that we check the FUZZY start- a plan that's supposed to occur 
  	#	this week does NOT occur in the past, even though we're past the beginning
  	#	of the week.
  	return (self.fuzzy_start < (Time.now - PLAN_PAST_SECS))
  end

  #MES- Has this plan been cancelled?
  def cancelled?
    #MES- If all the planner statuses are cancelled, then we're cancelled
    planners.detect{ |pl| Plan::STATUS_CANCELLED != pl.cal_pln_status.to_i }.nil?
  end

  def cancel
    #MGS- to cancel a plan, set all of the calendars on this plan to Plan::STATUS_CANCELLED
    self.planners.each do | cal |
      cal.cancel_plan(self)
    end
  end

  def uncancel(requesting_user)
    #MGS- before uncancelling a plan, delete all of the previous RSVP PlanChanges....
    # These changes are currently not interesting to the app, but there is a chance
    # that in the future that these changes will become relevant.
    PlanChange.delete_all(["plan_id = ? AND change_type = ?", self.id, PlanChange::CHANGE_TYPE_RSVP])

    #MES- To uncancel a plan, re-invite all users- confirm the requesting user
    requesting_planner = requesting_user.planner
    self.planners.each do | cal |
      if requesting_planner == cal
        #MES- This is the user who's uncancelling
        cal.accept_plan(self)
      else
        cal.add_plan(self)
      end
    end
  end

  def <=>(other)
    #MES- If the fuzzy start dates aren't the same, compare by that.
    # We want to order things by the LAST day on which they could occur.
    # For example, if one plan is happening on Thursday, and another could
    # happen on Wednesday, Thursday, or Friday, we want the first plan to be
    # ordered first.  We do NOT include time in this comparison, since we don't
    # want to put a plan that's Thursday at 8 PM after a plan that's at 2 PM
    # on Wednesday or Thursday.
    if !fuzzy_start.nil? && !other.fuzzy_start.nil?
      compare = (fuzzy_start.tv_day <=> other.fuzzy_start.tv_day)
      return compare if 0 != compare
    end

    #MES- Compare by the fuzziness of the plans.  We want exact plans to
    # show before fuzzy plans, and shorter span fuzzy plans to show before
    # longer span fuzzy plans.  For example, if there are three plans
    # scheduled for [Thursday], for [Wednesday or Thursday], and for
    # [Tuesday, Wednesday, or Thursday], we want the plans to sort in that order.
    if !fuzzy_start.nil? && !start.nil? && !other.fuzzy_start.nil? && !other.start.nil?
      compare = ((fuzzy_start - start) <=> (other.fuzzy_start - other.start))
      return compare if 0 != compare
    end

    #MES- If the start dates aren't the same, compare by that- earlier plans
    # appear earlier in the list.
    if !start.nil? && !other.start.nil?
      compare = (start <=> other.start)
      return compare if 0 != compare
    end

    #MES- The dates and times are exactly the same, compare by name
    if !name.nil? && !other.name.nil?
      compare = (name <=> other.name)
      return compare if 0 != compare
    end

    #MES- Everything relevant seems the same, compare by ID.  This way,
    # events created earlier will sort earlier, and events that are not
    # the same (i.e. the same object) will not return 0 for <=>.
    return (id <=> other.id)
  end

  #MES- A helper method to add a comment to this plan.
  def add_comment(user, text, type = PlanChange::CHANGE_TYPE_COMMENT)
    #MGS- create comment, fill it with stuff, and save it
    change = plan_changes.build(:comment => text, :owner_id => user.id, :change_type => type)

    if change.save
      @do_not_notify_list ||= []
      all_im_ins = User.find_associated_with_plan(id)
      im_ins_should_be_notified = all_im_ins.reject{ |in_user| in_user.id == user.id || @do_not_notify_list.include?(in_user)}
      im_ins_should_be_notified.each{ |in_user| in_user.handle_plan_comment(self, change, user) }
    else
      #MGS- TODO handle error?
    end
  end

  def comment_access_level(usr)
    #MGS- centralized way to determine comment access levels
    # You can now add comments on a plan that you are not on the invite list for.
    # We also need to allow for the edge case of allowing users to edit/delete an existing comment
    # that they made on a plan even when they might not have access to add a new comment because
    # the user they were getting access through changed either their status on the plan or changed
    # their friend relationship with the viewing user.

    if !usr.nil? && (usr.planner.plans.include?(self) || User.accepted_users_have_relationship?(usr.id, self.id))
      #MGS- if the current user is on the plan invite list or if the user has been
      # set as a friend/contact by someone on the accept list then they always have access to
      # add/edit/delete comments
      return PlansController::COMMENT_ACCESS_LEVEL_FULL
    else
      #MGS- current user shouldn't be able to see comments about this plan and shouldn't be
      # able to add/edit/delete comments either
      return PlansController::COMMENT_ACCESS_LEVEL_NONE
    end
  end


###############################################################
########  Change management
###############################################################

  def checkpoint_for_revert(user)
    #MES- Use this function BEFORE changing this item, to record the 'current' state of the item
    # If the item is changed and saved, the delta will be recorded as a Change object
    #MES- Unfortunately, we need to know the user.  If not for that, we could just do this work in
    # an after_initialize function
    comment_changes = self.plan_changes.select { |pc| pc.comment? }
    @revert_info = [user, user.tz, self.place_id, self.start, self.timeperiod, self.fuzzy_start, self.duration, comment_changes.length]
  end

  def comment_for_change(comment)
    #MGS- sets an instance variable that contains the comment for a change
    # the after_save_handler looks for this variable and sets it as the PlanChange.comment
    @change_comment = comment
  end

  def after_save_handler
    #MES- This function will create a comment that contains information needed to revert
    # the item to previous values IF the current values do not match the previous values.
    # The revertable_info argument should be in the format returned by the get_revertable_info
    # function.
    # It returns the comment that was created, or nil if no such comment was created.

    #MES- Is there any revert info?
    if !@revert_info.nil?
      #MES- Unpack the revert info
      user, tz, original_place_id, original_start, original_timeperiod, original_fuzzy_start, original_duration, original_comment_changes = @revert_info[0], @revert_info[1], @revert_info[2], @revert_info[3], @revert_info[4], @revert_info[5], @revert_info[6]
      #MES- Did things change?
      items_changed = []
      if (original_place_id.nil? != self.place_id.nil?) || (!original_place_id.nil? && !self.place_id.nil? && original_place_id != self.place_id)
        #MES- The place changed

        #MES- If there are NOT any place change objects for this plan, we want to make TWO
        # place change objects- one for the change we're making, and one for the "original change",
        # i.e. for the plan as it was originally created.  This way, a user can revert to the
        # original place.
        #MES- Side note- we do NOT want to make an 'original' PlanChange if the original place was empty.
        # See ticket 1077.
        if !has_change_of_type?(PlanChange::CHANGE_TYPE_PLACE) && !original_place_id.nil?
          #MES- NOTE: We do NOT add this change to items_changed, since we do NOT want
          # to notify users of this change.
          plan_changes << create_place_change(owner, nil, original_place_id, nil, self.created_at)
        end

        items_changed << create_place_change(user, original_place_id, self.place_id, @change_comment)

        #MES- We also have to update the cache info about which plans occur at
        #  which places.  This info is stored in the planners_plans table.
        perform_update_sql(['UPDATE planners_plans SET place_id_cache = ? WHERE plan_id = ?', self.place_id, self.id])
      end

      if !original_start.nil? && (original_start != self.start || original_fuzzy_start != self.fuzzy_start || original_duration != self.duration || original_timeperiod != self.timeperiod)
        #MES- The time changed

        #MES- If there are NOT any time change objects, make two (see comments above about place)
        if !has_change_of_type?(PlanChange::CHANGE_TYPE_TIME)
          #MES- NOTE: We do NOT add this change to items_changed, since we do NOT want
          plan_changes << create_time_change(owner, nil, nil, nil, nil, original_start, original_timeperiod, original_fuzzy_start, original_duration, nil, self.created_at)
        end

        items_changed << create_time_change(user, original_start, original_timeperiod, original_fuzzy_start, original_duration, self.start, self.timeperiod, self.fuzzy_start, self.duration, @change_comment)
      end

      #MES- Create the change object if there was anything to do
      if !items_changed.empty?
        #MES- Copy the stuff over to the items_changed list
        items_changed.each { | pc | plan_changes << pc}

        #KS- handle notifications for users who said "I'll Be There" except for people
        # on the email (if the plan was created via email), and the person who
        # made the change.
        @do_not_notify_list ||= []
        all_im_ins = User.find_associated_with_plan(id)
        im_ins_should_be_notified = all_im_ins.reject{ |in_user| in_user.id == user.id || @do_not_notify_list.include?(in_user)}
        im_ins_should_be_notified.each{ |in_user| in_user.handle_plan_updated(self, items_changed, user) }
      end
    end


    #MES- Another detail- if the security level changed, we need to fix up any cache of the info
    if @security_changed
      perform_update_sql(['UPDATE planners_plans SET plan_security_cache = ? WHERE plan_id = ?', self.security_level, self.id])
    end
  end

  #MES- A helper function to create PlanChange objects that reflect a change of place
  def create_place_change(user, original_place_id, new_place_id, comment, change_time = nil)
    orig_place = original_place_id.nil? ? nil : Place.find_by_id(original_place_id.to_i)
    new_place = new_place_id.nil? ? nil : Place.find_by_id(new_place_id.to_i)
    pc = PlanChange.new()
    pc.place_changed(user, orig_place, new_place, change_time)
    #MGS- optionally set the comment for this change
    pc.comment = comment if !comment.nil?
    pc.save
    return pc
  end

  #MES- A helper function to create PlanChange objects that reflect a change of time
  def create_time_change(user, original_start, original_timeperiod, original_fuzzy_start, original_duration, new_start, new_timeperiod, new_fuzzy_start, new_duration, comment, change_time = nil)
    pc = PlanChange.new()
    pc.time_changed(user, original_start, original_timeperiod, original_fuzzy_start, original_duration, new_start, new_timeperiod, new_fuzzy_start, new_duration, change_time)
    #MGS- optionally set the comment for this change
    pc.comment = comment if !comment.nil?
    pc.save
    return pc
  end

  def revert_from_change(change)
    #MES- This function takes in change object
    # and resets member variables as indicated by the change.

    if !change.nil?
      case change.change_type
        when PlanChange::CHANGE_TYPE_PLACE
          self.place = change.final_place
        when PlanChange::CHANGE_TYPE_TIME
          self.start, self.timeperiod, self.fuzzy_start, self.duration = change.final_time
        else
      end
    end
  end

  def has_change_of_type?(change_type)
    #MES- Does our list of changes contain a change with the indicated type?
    plan_changes.any? { | pc | pc.change_type == change_type }
  end

  #MES- Do not notify the user of this change to this plan.
  # This is used when the user already knows of the change (e.g. because they got an email
  # from the person making the change.)
  def do_not_notify(usr)
    @do_not_notify_list ||= []
    @do_not_notify_list << usr
  end


###############################################################
########  Date/Time Helpers
###############################################################


  def start_in_tz(timezone)
    timezone.utc_to_local(start)
  end

  def fuzzy_start_in_tz(timezone)
    timezone.utc_to_local(fuzzy_start)
  end

  def dateperiod(timezone)
    Plan::dateperiod_for_date(timezone, start, fuzzy_start)
  end

  def set_datetime(timezone, date_info, time_info, duration = 120)
    #MES- Set the date and time for this plan.
    #  timezone is a TZInfo::Timezone object that describes the timezone that the dates and times are in
    #  date can be a constant (such as DATE_DESCRIPTION_TOMORROW), or an array containing [year, month day], or nil
    #  time can be a constant (such as TIME_DESCRIPTION_LUNCH), or an array containing [hour, minute, second], or nil
    #  duration is the duration of the plan in minutes.  This argument will not be used if
    #  time is a constant.

    if date_info.nil?
      #MES- No date was supplied, we do NOT want to change any current date
      if !self.start.nil?
        date_info = timezone.utc_to_local(self.start).to_numeric_date_arr
        fuzzydate_info = timezone.utc_to_local(self.fuzzy_start).to_numeric_date_arr
      else
        date_info, fuzzydate_info = Plan.convert_dateperiod_to_date_info(timezone, DEFAULT_DATE)
      end
    else
      #MES- Convert any constants to the corresponding date/time
      if date_info.is_a? Numeric
        dateperiod = date_info.to_i
        date_info, fuzzydate_info = Plan.convert_dateperiod_to_date_info(timezone, dateperiod)
      else
        fuzzydate_info = date_info
      end
    end

    if time_info.nil?
      #MES- No time was supplied, don't change any existing time
      if !self.start.nil?
        time_info = timezone.utc_to_local(self.start).to_numeric_time_arr
        timeperiod_info = self.timeperiod
        duration = self.duration
      else
        #MES- There was never a time, set the time and the duration to default
        default_info = TIME_DESC_TO_TIME_MAP[DEFAULT_TIME]
        time_info = [default_info[0], default_info[1], 0]
        timeperiod_info = DEFAULT_TIME
        duration = default_info[2]
      end
    else
      if time_info.is_a? Numeric
        timeperiod = time_info.to_i
        timeperiod_info = time_info
        time_info, duration = Plan.convert_timeperiod_to_time_info(timeperiod)
      else
        timeperiod_info = TIME_DESCRIPTION_CUSTOM
      end
    end

    #MES- Now date and fuzzydate should be an array of [year, month, day] and
    # time should be an array of [hour, minute, second] all in local time, and
    # timeperiod_info should be the relevant timeperiod
    local_date_time = Time.local(date_info[0], date_info[1], date_info[2], time_info[0], time_info[1], time_info[2])
    self.start = timezone.local_to_utc(local_date_time)
    self.timeperiod = timeperiod_info
    local_fuzzy_date_time = Time.local(fuzzydate_info[0], fuzzydate_info[1], fuzzydate_info[2], time_info[0], time_info[1], time_info[2])
    self.fuzzy_start = timezone.local_to_utc(local_fuzzy_date_time)

    #MES- Also record the LOCAL time for the plan (if it's definite.)  This is used for reporting
    # usage statistics, etc.
    if (local_date_time == local_fuzzy_date_time)
      self.local_start = local_date_time
    else
      self.local_start = nil
    end

    self.duration = duration
  end

#MES- TODO: Think about internationalizing this.  That'll be tough, since
#  date and time conventions are different for different locales.
  def english_for_datetime(timezone)
    Plan::english_for_specified_datetime(timezone, start, timeperiod, fuzzy_start, duration)
  end

  def english_for_date(timezone)
    Plan::english_for_specified_date(timezone, start, fuzzy_start)
  end

  def english_for_time(timezone)
    Plan::english_for_specified_time(timezone, start, timeperiod, duration)
  end




###############################################################
########  Finders
###############################################################

  def self.find_at_place(place_id, max = 5)
#MES- TODO: Should this ALSO include plans that are on planners for which the
# "current" user is a friend, and the visibility of the planner is "friends"?
    #MES- Find plans that are publicly viewable and occur at the indicated place.
    # Limit to the first *max* plans, ordered by ??????

    #MES- Note:  We do NOT check if the place is public.  Finding plans for
    # a private place is not currently considered a breach of place security.

    #MGS- Adding check to not display plans with null or empty plan names
    # This keeps the UI display of the recent plans simpler and more interesting.

    if place_id.is_a?(Place)
      place_id = place_id.id
    end

#MES- TODO: What should it be ordered by?
    plans_cols = cols_for_select
    sql = <<-END_OF_STRING
      SELECT
        #{plans_cols}, MAX(planners_plans.planner_id) as planner_id
      FROM
        plans, planners_plans
      WHERE
        plans.id = planners_plans.plan_id AND
        plans.name IS NOT NULL AND
        plans.name <> '' AND
        planners_plans.cal_pln_status IN (?) AND
        planners_plans.place_id_cache = ? AND
        planners_plans.planner_visibility_cache = #{SkobeeConstants::PRIVACY_LEVEL_PUBLIC} AND
        planners_plans.plan_security_cache= #{Plan::SECURITY_LEVEL_PUBLIC}
      GROUP BY
        #{plans_cols}
      ORDER BY
        plans.start DESC,
        plans.name,
        plans.id
      LIMIT ?
    END_OF_STRING

    self.find_by_sql [sql, STATUSES_ACCEPTED, place_id, max]

  end

  def self.find_latest_plans(user = nil, limit = 5)
#MES- TODO: Should this ALSO include plans that are on planners for which the
# "current" user is a friend, and the visibility of the planner is "friends"?
    #MES- Find plans that are publicly viewable.
    # Limit to the first *limit* plans, ordered by ??????

#MES- TODO: What should it be ordered by?
    sql = nil
    plans_cols = cols_for_select('p')
    if !user.nil? && !user.lat_max.nil? && !user.lat_min.nil? && !user.long_max.nil?  && !user.long_min.nil?
      #MES- We know the geocode info for the user- only show plans for users
      #  that are near the user
      sql = <<-END_OF_STRING
        SELECT
          #{plans_cols}, MAX(planners_plans.planner_id) as planner_id
        FROM
          plans AS p, planners_plans, users
        WHERE
          p.id = planners_plans.plan_id AND
          p.fuzzy_start > UTC_TIMESTAMP() AND
          planners_plans.cal_pln_status IN (?) AND
          planners_plans.planner_visibility_cache = #{SkobeeConstants::PRIVACY_LEVEL_PUBLIC} AND
          planners_plans.plan_security_cache = #{Plan::SECURITY_LEVEL_PUBLIC} AND
          planners_plans.plan_id > ((SELECT MAX(id) FROM plans) - #{LATEST_PLANS_ID_FUDGE_FACTOR}) AND
          planners_plans.user_id_cache = users.id AND
          users.lat < ? AND users.lat > ? AND users.long < ? AND users.long > ?
        GROUP BY
          #{plans_cols}
        ORDER BY
          p.start ASC,
          p.name,
          p.id
        LIMIT ?
      END_OF_STRING

      return self.find_by_sql([sql, STATUSES_ACCEPTED, user.lat_max, user.lat_min, user.long_max, user.long_min, limit])
    else
      #MES- We don't know where the user is, so list all plans, regardless of
      #  the location of the user with the plan
      sql = <<-END_OF_STRING
        SELECT
          #{plans_cols}, MAX(planners_plans.planner_id) as planner_id
        FROM
          plans AS p, planners_plans
        WHERE
          p.id = planners_plans.plan_id AND
          p.fuzzy_start > UTC_TIMESTAMP() AND
          planners_plans.cal_pln_status IN (?) AND
          planners_plans.planner_visibility_cache = #{SkobeeConstants::PRIVACY_LEVEL_PUBLIC} AND
          planners_plans.plan_security_cache = #{Plan::SECURITY_LEVEL_PUBLIC} AND
          planners_plans.plan_id > ((SELECT MAX(id) FROM plans) - #{LATEST_PLANS_ID_FUDGE_FACTOR})
        GROUP BY
          #{plans_cols}
        ORDER BY
          p.start ASC,
          p.name,
          p.id
        LIMIT ?
      END_OF_STRING

      return self.find_by_sql([sql, STATUSES_ACCEPTED, limit])
    end
  end

  #MES- Returns all plans that are likely matches to the email passed in
  def self.find_by_email(email, user)
    #MES- First, try to find the plan based on the email "to"
    # address- for some emails, we put the plan id into the
    # email "from" (which will turn into the "to" when someone
    # responds.)
    plan_id = EmailId.plan_id_from_email(email)
    if !plan_id.nil?
      return [find(plan_id)].compact
    end

    #KS: try to do a lookup by the In-Reply-To and References
    # headers
    ids = []
    ids.concat(email.in_reply_to) if (!email.in_reply_to.nil? && !email.in_reply_to.empty?)
    ids.concat(email.references) if (!email.references.nil? && !email.references.empty?)
    if !ids.empty?
      sql = <<-END_OF_STRING
        SELECT
          DISTINCT plans.*
        FROM
          #{Plan.table_name} AS plans,
          #{EmailId.table_name} AS email_ids,
          planners_plans
        WHERE
          email_ids.email_id IN (?) AND
          email_ids.plan_id = plans.id AND
          plans.id = planners_plans.plan_id AND
          planners_plans.user_id_cache = ?
      END_OF_STRING

      plans = self.find_by_sql [sql, ids, user.id]

      #MES- If we found plans, return them
      if 0 < plans.length
        return plans
      end
    end

    #MES- We didn't find any hits by looking at the email ID.  How about trying to
    # match on subject?
    # This is for repairing "broken chains", where users sent emails between each other
    # and then forwarded to Skobee (the intermediate email exchange overwrote relevant
    # In-Reply-To information.)
    # Note that subject matching is ONLY a good idea if the email is a reply.
    # If the email is "fresh" (i.e. is not a reply), then it cannot refer to an
    # existing plan, so we shouldn't look.
    #MES- NOTE: Exchange seems to NEVER add In-Reply-To or References headers, so
    # for Exchange we're going to make our decision based on whether the subject
    # starts with "RE: "
    if (!email.subject.nil? && !email.subject.empty?) &&
        ( !ids.empty? ||
          (email.from_exchange? && email.subject.match(/^[Rr][Ee]:\s/))
        )
      canonical_subject = EmailId.canonicalize_subject(email.subject)

      subject_sql = <<-END_OF_STRING
        SELECT
          DISTINCT plans.*
        FROM
          #{Plan.table_name} AS plans,
          #{EmailId.table_name} AS email_ids,
          planners_plans
        WHERE
          email_ids.canonical_subject = ? AND
          email_ids.plan_id = plans.id AND
          plans.id = planners_plans.plan_id AND
          planners_plans.user_id_cache = ?
      END_OF_STRING

      subject_plans = self.find_by_sql [subject_sql, canonical_subject, user.id]

      #MES- If we found plans, return them
      if 0 < subject_plans.length
        return subject_plans
      end
    end

    #MES- No dice, return an empty array
    return []
  end



###############################################################
########  Other Class methods
###############################################################

  def self.dateperiod_for_date(timezone, start, fuzzy_start)
    #MES- Returns the date period (e.g. DATE_DESCRIPTION_TOMORROW) corresponding to the
    #  date for this plan.  If the current date doesn't correspond to a named date period,
    #  DATE_DESCRIPTION_CUSTOM is returned.

    #MES- Is the info we need available?
    if start.nil?
      return DATE_DESCRIPTION_CUSTOM
    end
    
    timezone = User::DEFAULT_TIME_ZONE_OBJ if timezone.nil?

    #MES- Is it a day long?
    start_local = timezone.utc_to_local(start)
    startdate = Date.civil(start_local.year, start_local.mon, start_local.day)
    fuzzystart_local = timezone.utc_to_local(fuzzy_start)
    fuzzy_startdate = Date.civil(fuzzystart_local.year, fuzzystart_local.mon, fuzzystart_local.day)
    today_tz = Date.today_tz(timezone)

    #MES- Is it a day long?
    if startdate == fuzzy_startdate
      #MES- Daylong plan
      case (startdate - today_tz).floor
        when 0: return DATE_DESCRIPTION_TODAY
        when 1: return DATE_DESCRIPTION_TOMORROW
        when -1: return DATE_DESCRIPTION_YESTERDAY
        else
          return FUZZY_FUTURE_DATE == startdate ? DATE_DESCRIPTION_FUTURE : DATE_DESCRIPTION_CUSTOM
      end
    #MES- Is it a week long?
    elsif (fuzzy_startdate - startdate) == 6
      #MES- Weeklong plan
      #MES- Does it start at the beginning of a week?
      if Date::WEEK_START_DAY == startdate.wday
        #MES- OK, it's on a week boundary.  What week is it?
        diff = (today_tz - startdate).floor
        if 0 <= diff && diff < 7
          return DATE_DESCRIPTION_THIS_WEEK
        elsif 7 <= diff && diff < 14
          return DATE_DESCRIPTION_LAST_WEEK
        elsif -7 <= diff && diff < 0
          return DATE_DESCRIPTION_NEXT_WEEK
        else
          return DATE_DESCRIPTION_CUSTOM
        end
      end
    #MGS- Is it a weekend?
    # should be a length of two days with the start on a Saturday (6) and the fuzzy start on a Sunday (0)
    elsif 1 == (fuzzy_startdate - startdate) && 0 == fuzzy_startdate.wday && 6 == startdate.wday
      diff = (today_tz - startdate).floor
      #MGS- this weekend can be from -5 the (difference btw Saturday and Monday)
      # to 1 (difference btw today of Sunday and startdate of Saturday)
      if -5 <= diff && diff < 2
        return DATE_DESCRIPTION_THIS_WEEKEND
      #MGS- next weekend
      elsif -12 <= diff && diff < -5
        return DATE_DESCRIPTION_NEXT_WEEKEND
      #MGS- could be any other weekend, last weekend, four weekends from now, etc.
      else
        return DATE_DESCRIPTION_CUSTOM
      end
    #MES- Does it start on the first day of a month and end on the last day of a month?
    elsif 1 == startdate.mday && 1 == fuzzy_startdate.succ.mday && startdate.mon == fuzzy_startdate.mon && startdate.year == fuzzy_startdate.year
      #MES- It's a month, what month is it?
      if startdate.mon == today_tz.mon && startdate.year == today_tz.year
        return DATE_DESCRIPTION_THIS_MONTH
      #MES- Months are tricky- if the month is one more than this month, and the year is the same, it's
      #  next month.  But what if this month is December?  Then the next month is "1", and the year
      #  is one more.
      elsif  (startdate.mon == (today_tz.mon + 1) && startdate.year == today_tz.year)  ||
              (startdate.mon == 1 && today_tz.mon == 12 && startdate.year == (today_tz.year + 1))
        return DATE_DESCRIPTION_NEXT_MONTH
      elsif  (startdate.mon == (today_tz.mon - 1) && startdate.year == today_tz.year)  ||
              (startdate.mon == 12 && today_tz.mon == 1 && startdate.year == (today_tz.year - 1))
        return DATE_DESCRIPTION_LAST_MONTH
      else
          return DATE_DESCRIPTION_CUSTOM
      end
    end

    #MES- None of the above
    return DATE_DESCRIPTION_CUSTOM
  end

  def self.convert_dateperiod_to_date_info(timezone, period)
    #MES- Returns start_date, fuzzy_start_date (as Time objects in timezone)

    raise "Invalid date period #{period}" if period <= DATE_DESCRIPTION_CUSTOM || period >= DATE_DESCRIPTION_INVALID

    now = timezone.now
    today = Date.civil(now.year, now.mon, now.day)
    case period
    when DATE_DESCRIPTION_TODAY
      new_start = new_fuzzy_start = today.to_numeric_arr
    when DATE_DESCRIPTION_TOMORROW
      tomorrow = today + 1
      new_start = new_fuzzy_start = tomorrow.to_numeric_arr
    when DATE_DESCRIPTION_YESTERDAY
      yesterday = today - 1
      new_start = new_fuzzy_start = yesterday.to_numeric_arr
    when DATE_DESCRIPTION_THIS_WEEKEND
      #MGS- Sundays are a special case;
      #MGS- if today is a Sunday, then this weekend is really the weekend we are currently in
      if today.wday == 0
        weekend_begin = today - 1
        weekend_end = today
      else
        week_begin = today.zero_day_of_week
        weekend_begin = week_begin + 6
        weekend_end = week_begin + 7
      end
      new_start = weekend_begin.to_numeric_arr
      new_fuzzy_start = weekend_end.to_numeric_arr
    when DATE_DESCRIPTION_NEXT_WEEKEND
      #MGS- Sundays are a special case;
      #MGS- if today is a Sunday, next weekend is really the weekend 6 days from now
      if today.wday == 0
        weekend_begin = today + 6
        weekend_end = today + 7
      else
        week_begin = today.zero_day_of_week
        weekend_begin = week_begin + 13
        weekend_end = week_begin + 14
      end
      new_start = weekend_begin.to_numeric_arr
      new_fuzzy_start = weekend_end.to_numeric_arr
    when DATE_DESCRIPTION_THIS_WEEK
      week_begin = today.beginning_of_week
      new_start = week_begin.to_numeric_arr
      week_end = week_begin + 6
      new_fuzzy_start = week_end.to_numeric_arr
    when DATE_DESCRIPTION_NEXT_WEEK
      next_week_begin = (today + 7).beginning_of_week
      new_start = next_week_begin.to_numeric_arr
      next_week_end = next_week_begin + 6
      new_fuzzy_start = next_week_end.to_numeric_arr
    when DATE_DESCRIPTION_LAST_WEEK
      last_week_begin = today.beginning_of_week - 7
      last_week_end = last_week_begin + 6
      new_start = last_week_begin.to_numeric_arr
      new_fuzzy_start = last_week_end.to_numeric_arr
    when DATE_DESCRIPTION_THIS_MONTH
      month_begin = today.beginning_of_month
      month_end = today.next_month_start - 1
      new_start = month_begin.to_numeric_arr
      new_fuzzy_start = month_end.to_numeric_arr
    when DATE_DESCRIPTION_NEXT_MONTH
      next_month_begin = today.next_month_start
      next_month_end = next_month_begin.next_month_start - 1
      new_start = next_month_begin.to_numeric_arr
      new_fuzzy_start = next_month_end.to_numeric_arr
    when DATE_DESCRIPTION_LAST_MONTH
      last_month_end = today.beginning_of_month - 1
      last_month_begin = last_month_end.beginning_of_month
      new_start = last_month_begin.to_numeric_arr
      new_fuzzy_start = last_month_end.to_numeric_arr
    when DATE_DESCRIPTION_FUTURE
      new_start = FUZZY_FUTURE_DATE.to_numeric_arr
      new_fuzzy_start = FUZZY_FUTURE_DATE.to_numeric_arr
    end

    return new_start, new_fuzzy_start
  end

  def self.convert_timeperiod_to_time_info(period)
    #MES- Returns start_time (as an array of hour, minute), duration (in minutes)
    #MES- Check that it's a valid period
    raise "Invalid time period #{period}" if period <= TIME_DESCRIPTION_CUSTOM || period >= TIME_DESCRIPTION_INVALID

    #MES- If the time is "unset", set it to unset, which is indicated by a NIL duration
    if TIME_DESCRIPTION_NOT_SET == period
      return [[0, 0], nil]
    end

    #MES- Set it to the parameters for the item
    info = TIME_DESC_TO_TIME_MAP[period]
    return [[info[0], info[1]], info[2]]
  end

  def self.english_for_specified_day_of_week(day_number)
    if day_number >= 0 && day_number < Date::DAYNAMES.length
      return Date::DAYNAMES[day_number]
    else
      return 'day undefined'
    end
  end

  def self.english_for_specified_datetime(timezone, start, timeperiod, fuzzy_start, duration)
    "#{Plan::english_for_specified_date timezone, start, fuzzy_start},  #{Plan::english_for_specified_time timezone, start, timeperiod, duration}"
  end

  def self.english_for_specified_date(timezone, start, fuzzy_start)
    #MES- Did we get a timezone?
    if timezone.nil?
    	timezone = User::DEFAULT_TIME_ZONE_OBJ
   	end
   	
    date_per = dateperiod_for_date(timezone, start, fuzzy_start)
    if DATE_DESCRIPTIONS.include? date_per
      return DATE_DESCRIPTIONS[date_per]
    end

    today = timezone.now
    current_year = today.year

    display_start = timezone.utc_to_local(start)
    display_fuzzy_start = timezone.utc_to_local(fuzzy_start)

    if start == fuzzy_start
      year = (current_year == display_start.year && current_year == display_fuzzy_start.year) ? '' : ', %Y'
      display_start.strftime('%a %b %d' + year)
    else
      display_fuzzy_start = timezone.utc_to_local(fuzzy_start)
      "Bet. #{display_start.strftime('%a %b %d')} and #{display_fuzzy_start.strftime('%a %b %d')}"
    end
  end

  def self.english_for_specified_time(timezone, start, timeperiod, duration)
    #MES- TODO: Use timeperiod to simplify this code
    #MES- TODO: Support military time?  It's clearer and more concise.

    return '[no time]' if duration.nil?
    
    #MES- Did we get a timezone?
    using_default_timezone = false
    if timezone.nil?
    	timezone = User::DEFAULT_TIME_ZONE_OBJ
    	using_default_timezone = true
    end

    time_local_to_user = timezone.utc_to_local(start)
    #MES- Is this a known timeperiod (e.g. "Lunch"?
    if TIME_DESC_TO_ENGLISH_MAP.has_key?(timeperiod)
      #MES- It's a specific period, like "Lunch".  But is it lunch in the timezone of the viewer?
      expected_time_info = convert_timeperiod_to_time_info(timeperiod)[0]
      #MES- If the time doesn't jive with what that period would be in the timezone of the current user, OR 
      # it's "all day", don't show the time also- just show the description.
      #	On the other hand, if we're using a default timezone, then we just want to show the map entry
      if using_default_timezone || (time_local_to_user.hour == expected_time_info[0] && time_local_to_user.min == expected_time_info[1]) || TIME_DESCRIPTION_ALL_DAY == timeperiod
        #MES- It's in the right timezone, show the period description
        return TIME_DESC_TO_ENGLISH_MAP[timeperiod]
      else
        #MES- It's NOT in the right timezone, show the period, supplemented with an exact time
        return "#{TIME_DESC_TO_ENGLISH_MAP[timeperiod]} (#{short_description_for_time(time_local_to_user)})"
      end
    else
      #MES- We don't have a standard description for this time, make a nonstandard one
      return short_description_for_time(time_local_to_user)
    end
  end

  def self.short_description_for_time(time)
    hr = time.hour_12
    if 0 == time.min
      return time.strftime("#{hr} %p")
    else
      return time.strftime("#{hr}:%M %p")
    end
  end

  private
  
  def truncate_description
    #MGS- we want to silently handle the case where the user enters more text than we can handle for the body (like flickr)
    # only saving the first 4096 characters.
    self.description.slice!(4096..-1) if !self.description.nil?
  end
end
