class Planner < ActiveRecord::Base

  after_save :after_save_handler

  #KS- privacy options for planners (special case)
  PLANS_PRIVACY_SETTINGS = [
    SkobeeConstants::PRIVACY_LEVEL_PUBLIC,
#KS- commenting this out for now because we aren't gonna do it in v1
#TODO: put contacts-based security in
#    SkobeeConstants::PRIVACY_LEVEL_CONTACTS,
    SkobeeConstants::PRIVACY_LEVEL_FRIENDS,
    SkobeeConstants::PRIVACY_LEVEL_PRIVATE ].freeze

  USER_VISIBILITY_LEVEL_AVAILABILITY  = 0  #MES- Only see availability information for this planner
  USER_VISIBILITY_LEVEL_DETAILS       = 1  #MES- May see plan names and details such as invite lists.
  USER_VISIBILITY_LEVEL_OWNER         = 2  #MES- Owner of the planner- may see all details

  PLAN_NOTIFICATION_STATE_NOTIFIED = 1     #MES- We use nil to indicate 'not notified'


  has_and_belongs_to_many :plans, :order => 'start, duration', :dynamic_conditions => 'get_dynamic_conditions'
  belongs_to :owner, :class_name => 'User'

  def set_plans_time_filter(usr)
    #MES- The dynamic filter will only include plans with a fuzzy_start that is
    # greater than or equal to the beginning of today (as considered by the
    # current user.)

    #MES- Find the beginning of today, and find plans with a fuzzy start after that
    tz = usr.tz
    day_begin_in_utc = tz.local_to_utc(tz.now.day_begin)
    @dynamic_conditions = "fuzzy_start >= '#{day_begin_in_utc.fmt_for_mysql()}'"

  end

  def get_dynamic_conditions
    return @dynamic_conditions
  end

  def after_save_handler
    #MES- If the visibility was changed, update the caches that store visibility data
    if @visibility_changed
      perform_update_sql(['UPDATE planners_plans SET planner_visibility_cache = ? WHERE planner_id = ?', self.visibility_type, self.id])
    end
  end

  def initialize(attributes = nil)
    super

    #MES- Set the default visibility
    @visibility_type = SkobeeConstants::PRIVACY_LEVEL_PUBLIC
    @visibility_changed = false
  end

  def visibility_type=(val)
    #MES- We want to capture the "on change" event, so we know to
    #  fix up caches that record this value on save
    @attributes['visibility_type'] = val
    @visibility_changed = true
  end

  def visibility_level(viewing_user)
    #MES- The visibility level indicates the access that the passed
    #  in user should have to this planner

		if !viewing_user.nil?
	    #MES- If an integer was passed in, convert it to an object
	    if viewing_user.kind_of? Numeric
	      viewing_user = User.find(viewing_user)
	    end
	
	    #MES- Is that user the owner or an administrator?
	    if viewing_user.id == self.owner.id || viewing_user.administrator?
	      return USER_VISIBILITY_LEVEL_OWNER
	
	    #MES- Is the planner private?
	    elsif (SkobeeConstants::PRIVACY_LEVEL_PRIVATE == self.visibility_type)
	      return USER_VISIBILITY_LEVEL_AVAILABILITY
	
	    #MGS- Removing USER_VISIBILITY_LEVEL_PLANS visibility level; this now displays DETAILS
	    elsif (SkobeeConstants::PRIVACY_LEVEL_PUBLIC == self.visibility_type)
	      return USER_VISIBILITY_LEVEL_DETAILS
	
	    #MGS- Is the user on the friends list of the owner?
	    elsif owner.friends.include?(viewing_user) && (SkobeeConstants::PRIVACY_LEVEL_FRIENDS == self.visibility_type)
	        return USER_VISIBILITY_LEVEL_DETAILS
	    else
	        return USER_VISIBILITY_LEVEL_AVAILABILITY
	    end
	  else
	  	#MES- The viewing user is nil, so the visibility level is whatever we'd show to the public
	  	if SkobeeConstants::PRIVACY_LEVEL_PUBLIC == self.visibility_type
	  		return USER_VISIBILITY_LEVEL_DETAILS
	  	else
	    	return USER_VISIBILITY_LEVEL_AVAILABILITY
	  	end	
	  end
  end

  def add_plan(plan)
    #MES- Add the indicated plan as "invited".  I.e. this planner should contain
    #  the indicated plan with status "invited."
    #NOTE: There may already be a record for the user, since they may have rejected the plan (which would leave a status of rejected.)
    plan.planners.push_or_update_attributes(self, add_default_atts(plan, :cal_pln_status => Plan::STATUS_INVITED))
    #MES- Record a PlanChange object
    #MES- NOTE: We do NOT want to add a PlanChange for invitations, as it clutters the UI!
    #create_plan_change_helper(owner, plan, Plan::STATUS_NO_RELATION, Plan::STATUS_INVITED)
  end

  def accept_plan(plan, usr = nil, ownership_status = nil, plan_status = Plan::STATUS_ACCEPTED, comment = nil)
    #MES- Accept the plan indicated by 'plan'.  Update the user
    #  indicated by 'usr' to have contacts for the other invitees,
    #  if not nil.  Set the ownership to ownership_status if it's not nil.
    initial_status = plan_status(plan)

    #MES- If they're already in the given state, then this is a no-op
    return if plan_status == initial_status

    statuses = add_default_atts(plan, :cal_pln_status => plan_status)
    statuses[:ownership] = ownership_status if !ownership_status.nil?
    plan.planners.push_or_update_attributes(self, statuses)
    #MES- We changed the planners for the plan, but that means self.plans
    # is out of date.  Uncache it.
    self.plans.reset
    #MES- If a user was passed in, the contacts for that user
    # will be updated to reflect acceptance of the plan,  If NO user
    # was passed in, we don't have a good way of figuring out which User
    # object should be updated (calling "owner" will give us AN instance of the
    # owner of the planner, but probably a DIFFERENT instance than the one that
    # the caller is using- since we need to invalidate the cache of contacts in
    # the PARTICULAR instance of User, we need to know exactly which instance
    # the client cares about.)
    usr.add_contacts_from_plan(plan) if !usr.nil?

    #MES- Record a PlanChange object
    create_plan_change_helper(owner, plan, initial_status, plan_status, comment)
  end

  def reject_plan(plan, comment = nil)
    plan = Plan.find(plan) if !(plan.is_a? Plan)
    initial_status = plan_status(plan)

    #MES- If they're already rejected, then this is a no-op
    return if Plan::STATUSES_REJECTED.member?(initial_status)

    plans.update_attributes(plan, :cal_pln_status => Plan::STATUS_REJECTED)
    #MES- Record a PlanChange object
    create_plan_change_helper(owner, plan, initial_status, Plan::STATUS_REJECTED, comment)
  end

  def cancel_plan(plan)
    plan = Plan.find(plan) if !(plan.is_a? Plan)
    initial_status = plan_status(plan)

    #MES- If they're already cancelled, then this is a no-op
    return if Plan::STATUS_CANCELLED == initial_status

    plans.update_attributes(plan, :cal_pln_status => Plan::STATUS_CANCELLED)
    create_plan_change_helper(owner, plan, initial_status, Plan::STATUS_CANCELLED)
  end

  def mark_plan_notified(pln, state = PLAN_NOTIFICATION_STATE_NOTIFIED)
    plans.update_attributes(pln, :reminder_state => state)
  end

  #MES- Mark that this user/planner viewed the indicated plan
  def viewed_plan(pln)
    #MES- Is the plan on the planner?
    if plans.include?(pln)
      plans.update_attributes(pln, :viewed_at => Time.now_utc)
    end
  end

  #MES- Of the plans associated with this planner, which are visible to the indicated user?
  # NOTE: This does NOT check the visiblity of the PLANNER, only of the PLANS
  def visible_plans(viewing_user_id)
    #MES- If the viewing user is the owner of this planner, then
    # they can see all the plans
    return plans if !viewing_user_id.nil? && viewing_user_id == self.user_id

    #MES- Other users can see all plans that are public
    return plans.find_all { |pln| pln.security_level == Plan::SECURITY_LEVEL_PUBLIC }
  end

  #MES- Returns a hash where the keys are the IDs of
  # plans on this planner that have unviewed changes (e.g.
  # plans that have a new comment since the user last viewed
  # the plan.)  Viewing time is controlled by the viewed_plan
  # function.
  def plan_ids_with_unviewed

    #MES- Select plan IDs for plans that are on our calendar,
    # that are taking place in the future, that we've accepted,
    # and that have relevant changes that took place AFTER we
    # viewed the plan
    sql = <<-END_OF_STRING
      SELECT
        plans.id AS id, count(*) as count
      FROM
        plans, planners_plans, plan_changes
      WHERE
        plans.id = planners_plans.plan_id AND
        planners_plans.planner_id = ? AND
        planners_plans.cal_pln_status IN (?) AND
        plans.fuzzy_start > UTC_TIMESTAMP() AND
        plan_changes.plan_id = planners_plans.plan_id AND
        (
          plan_changes.change_type IN (?) OR
          (plan_changes.change_type = ? AND plan_changes.comment IS NOT NULL)
        ) AND
        ((plan_changes.updated_at > planners_plans.viewed_at) OR planners_plans.viewed_at IS NULL) AND
        plan_changes.owner_id != ?
      GROUP BY plans.id
    END_OF_STRING

    res = {}
    rows = perform_select_all_sql([sql, self.id, Plan::STATUSES_ACCEPTED, PlanChange::CHANGE_TYPES_COMMENTS_AND_CHANGES, PlanChange::CHANGE_TYPE_RSVP, self.user_id])
    rows.each do | row |
      res[row['id'].to_i] = row['count'].to_i
    end
    return res
  end
  
  #MES- Returns the planner and user associated with the ID string.  If the
  #	ID string is a number (e.g. '234'), then the planner will be the planner with
  #	that ID, and the user will be the owner of the planner.  If the ID string is
  #	NOT a number (e.g. 'kavin620'), then the user will be the user with that login,
  #	and the planner will be the planner for the user.
  def self.find_p_and_u_by_id_or_login(id_str)
  	if id_str.contains_int?
  		#MES- The string is a number, then look up the planner
      plnr = Planner.find(id_str)
      #MES- Get the user from the planner
      return plnr, plnr.owner
  	else
  		#MES- The string is NOT a number, find the user by login
  		usr = User.find_by_login(id_str)
  		return usr.planner, usr
  	end
  end

  private

  #MES- A helper to get the current plan status for the indicated plan
  # for this planner.
  def plan_status(plan)
    cur_stat = Plan::STATUS_NO_RELATION
    existing_plan = self.plans.detect { | item | item.id == plan.id }
    cur_stat = existing_plan.cal_pln_status if !existing_plan.nil?
    return cur_stat
  end

  #MES- A helper that creates a PlanChange object for a change in RSVP status
  def create_plan_change_helper(user, plan, initial_status, final_status, comment = nil)
    #MES- Record a PlanChange object
    pc = PlanChange.new
    #MGS- set the comment on the plan change, unless the comment is blank
    pc.comment = comment unless comment.blank?
    pc.rsvp_changed(user, initial_status, final_status)
    pc.save
    plan.plan_changes << pc
    return pc
  end

  def add_default_atts(plan, current_atts)
    #MES- Add in attributes that should be in every record.
    #  Specifically, we cache the planner visibility and the
    #  place id into the join table for performance in lookups.
    res = current_atts.clone
    res[:planner_visibility_cache] = self.visibility_type
    res[:plan_security_cache] = plan.security_level
    place_id = 0
    place_id = plan.place_id if plan.place_id
    res[:place_id_cache] = place_id
    res[:user_id_cache] = self.owner.id
    return res
  end

  def self.convert_date_to_string(date)
    #KS- if the month is only one digit, add a zero to conform to sql's format
    month = date.mon
    month = "0#{month}" if "#{month}".length == 1

    #KS- if the day of month is only one digit, add a zero to conform to sql's
    #format
    day_of_month = date.mday
    day_of_month = "0#{day_of_month}" if "#{day_of_month}".length == 1

    "#{month}/#{day_of_month}/#{date.year}"
  end

  def self.get_set_complement(superset, subset)
    complement_set = []
    superset.each{|element|
      if !subset.include?(element)
        complement_set << element
      end
    }

    return complement_set
  end

  #MES- Name may be zero length, but may not be nil
  validates_each :name do |record, attr|
    record.errors.add attr, "planner name for planner #{self.id} is nil" if attr.nil?
  end

  validates_length_of :name, :within => 0..255
  validates_presence_of :owner
  validates_inclusion_of :visibility_type , :in => 0...SkobeeConstants::PRIVACY_LEVEL_INVALID

end
