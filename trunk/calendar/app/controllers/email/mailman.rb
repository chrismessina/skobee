require 'tmail'
require 'parsedate'
require 'net/pop'
require 'find'

class Mailman < ActionMailer::Base

  #MES- Commands as understood from the email
  COMMAND_WHO = 0
  COMMAND_WHAT = 1
  COMMAND_WHEN = 2
  COMMAND_WHERE = 3
  COMMAND_ADDRESS = 4
  COMMAND_OWNER = 5
  COMMAND_OWNER_NAME = 6
  COMMAND_EMAILS = 7
  COMMAND_ACCEPT = 8
  COMMAND_REJECT = 9
  COMMAND_INTERESTED = 10
  COMMAND_WHAT_SUBJECT = 11



  #MES- Constants to be recorded in the changes hash
  CHANGES_ACTION = 'action'
    CHANGES_ACTION_CREATE_PLAN = 'create'
    CHANGES_ACTION_ALTER_PLAN = 'alter'
  CHANGES_WHO = 'who'
    CHANGES_WHO_INVITED = 'invited'
    CHANGES_WHO_ACCEPTED = 'accepted'
    CHANGES_WHO_INTERESTED = 'interested'
    CHANGES_WHO_REJECTED = 'rejected'
    CHANGES_WHO_OWNER = 'owner'
  CHANGES_WHAT = 'what'
  CHANGES_WHERE = 'where'
  CHANGES_EMAIL_IDS = 'email_ids'
  CHANGES_WHEN = 'when'





  #MES- An array of identifiers for methods- basically a mapping of input string format
  # to what the string means.  Each entry in this array is an array containing three items.
  # The first item is a regexp that can be matched against an input string.
  # The second item is a group number in the regular expression that will be used to find the "arguments" to the item.
  # The third item is the COMMAND_XXX constant that this regexp maps to.
  COMMAND_IDENTIFIERS = [
#    [Regexp.compile('^\s*who:\s*(.*)\s*$', Regexp::IGNORECASE), 1, COMMAND_WHO], #MES- We don't support the WHO operator right now- we just use the WHO from the email.to and email.cc
    [Regexp.compile('^\s*what:\s*(.*)\s*$', Regexp::IGNORECASE), 1, COMMAND_WHAT],
    [Regexp.compile('^\s*when:\s*(.*)\s*$', Regexp::IGNORECASE), 1, COMMAND_WHEN],
    [Regexp.compile('^\s*time:\s*(.*)\s*$', Regexp::IGNORECASE), 1, COMMAND_WHEN],
    [Regexp.compile('^\s*where:\s*(.*)\s*$', Regexp::IGNORECASE), 1, COMMAND_WHERE],
    [Regexp.compile('^\s*place:\s*(.*)\s*$', Regexp::IGNORECASE), 1, COMMAND_WHERE],
    [Regexp.compile('^\s*address:\s*(.*)\s*$', Regexp::IGNORECASE), 1, COMMAND_ADDRESS],
    [Regexp.compile('^\s*(rsvp:\s*)?i\'?ll be there\s*$', Regexp::IGNORECASE), nil, COMMAND_ACCEPT],
    [Regexp.compile('^\s*(rsvp:\s*)?i\'?m in\s*$', Regexp::IGNORECASE), nil, COMMAND_ACCEPT],
    [Regexp.compile('^\s*(rsvp:\s*)?i\'?m interested\s*$', Regexp::IGNORECASE), nil, COMMAND_INTERESTED],
    [Regexp.compile('^\s*(rsvp:\s*)?i\'?m out\s*$', Regexp::IGNORECASE), nil, COMMAND_REJECT],
  ]


  EMAIL_FILE_PATTERN = /^email\..*/
  EMAIL_FILE_PROCESSING_PREFIX = 'processing.'
  EMAIL_FILE_ERROR_PREFIX = 'error.'
  EMAIL_RECEIVE_SLEEP_SECS = 1
  EMAIL_DB_CONNECT_ERROR_SLEEP_SECS = 6
  EMAIL_DB_CONNECT_ERROR_LIMIT = 10*60*24

  PINGBACK_COMMAND = 'PINGBACK'


  #MES- When we start, we've received zero emails
  @@num_received = 0
  @@num_successfully_processed = 0


  def receive(email)
    #MES- Record that we received an email
    @@num_received += 1

    commands = Mailman::parse_email(email)
    what_cmd = commands[COMMAND_WHAT] || commands[COMMAND_WHAT_SUBJECT]
    if what_cmd && PINGBACK_COMMAND == what_cmd
      #MES- The special "pingback" command causes us to respond with an email, but
      # take no other action.
      perform_pingback(email)
      #MES- We're done.
      return nil
    end

    owner = User.find_by_email(commands[COMMAND_OWNER])
    if owner.nil?
      #MES- This is an error- the person who sent the email is not recognized!
      raise "ERROR in Mailman::receive, user with email #{commands[COMMAND_OWNER]} not found!"
    end

    #MES- Set the owner's "real" name if we don't currently know it, but the email
    # suggests it.
    name = commands[COMMAND_OWNER_NAME]
    if owner.real_name.nil? && !name.nil? && !name.empty?
      owner.real_name = name
      owner.save
    end

    plan_matches = Plan.find_by_email(email, owner)
    #MES- If there was one match, that's the plan we want to edit.
    # If there were multiple matches, then we don't know which one
    # the user intended us to edit.  If there are zero matches, we
    # make a new plan.
    plan = nil
    if 1 == plan_matches.length
      plan = plan_matches[0]
    elsif 1 < plan_matches.length
      #MES- In this case, we don't know which plan the user intended for us to
      # edit, but we're pretty sure the user intended to edit a plan.
      # Since we don't know what to do, we'll just ask the user (i.e. we'll
      # give up and send them a reply email.)
      UserNotify.deliver_unknown_plan_for_email(owner, email, plan_matches)
      return nil
    end

    changes = {}
    if !plan
      #KS- only allow email plan creation if the user hasn't turned it off
      if owner.get_att_value(UserAttribute::ATT_ALLOW_PLAN_CREATION_VIA_EMAIL) != 0
        plan = create_plan(owner, commands, changes)
        #MES- Notify the creator via email that the plan was created
        created_place = false
        if changes.has_key?(CHANGES_WHERE)
           created_place = changes[CHANGES_WHERE][1]
        end
        UserNotify.deliver_created_plan(owner, plan, created_place)
      end
    else
      modify_plan(plan, owner, commands, changes)
    end

    #MES- Bump up the number of successfully processed emails
    @@num_successfully_processed += 1
    return plan
  end



  private


  #MES- Create a plan for the given owner.  Plan details
  # are specified in 'commands', and actions taken are recorded
  # in changes.
  def create_plan(owner, commands, changes)
    logger.info("In Mailman#create_plan, creating new plan")
    changes[CHANGES_ACTION] = CHANGES_ACTION_CREATE_PLAN
    plan = Plan.new
    Mailman::apply_commands(plan, owner, commands, changes)
    plan.save

    return plan
  end

  #MES- Modify the indicated plan for the given owner.  Plan details
  # are specified in 'commands', and actions taken are recorded
  # in changes.
  def modify_plan(plan, owner, commands, changes)
    #MES- Get the info about this plan for the planner
    pln_info = nil
    begin
      pln_info = plan.planners.find(owner.planner.id)
    rescue ActiveRecord::RecordNotFound
      #MES- Ignore a "planner not found" error- if the planner isn't on the plan, then we'll leave pln_info nil
    end
    
    #MES- Is this user allowed to modify this plan?
    if pln_info.nil?
      logger.info("In Mailman#modify_plan, user #{owner.id} not allowed to modify plan #{plan.id}")
      raise "ERROR in Mailman::modify_plan, user with email #{commands[COMMAND_OWNER]} does not have rights to edit plan #{plan.id}"
    end
    
    #MES- IF the plan is locked AND the user isn't a owner of the plan, then
    # the user cannot change the time, the invitees, etc.  They can STILL change
    # their own status.
    if (Plan::LOCK_STATUS_UNLOCKED != plan.lock_status && Plan::OWNERSHIP_OWNER != pln_info.ownership.to_i)
      #MES- They can't modify the plan, but they can still modify their status.
      # Remove all items from commands EXCEPT the COMMAND_OWNER, which sets the status for the current user
      commands.delete_if { |key, val| key != COMMAND_OWNER }
    end

    logger.info("In Mailman#modify_plan, modifying plan #{plan.id}")
    changes[CHANGES_ACTION] = CHANGES_ACTION_ALTER_PLAN
    #MES- Checkpoing the plan
    plan.checkpoint_for_revert(owner)

    Mailman::apply_commands(plan, owner, commands, changes)

    #MES- Save the changes
    plan.save
  end

##########################################################
####### Plan updating functions
##########################################################

  def self.apply_commands(plan, owner, commands, changes)
    #MES- Apply the commands in 'commands' to the indicated plan.
    apply_who(plan, owner, commands, changes)
    apply_what(plan, owner, commands, changes)
    apply_where(plan, owner, commands, changes)
    apply_owner(plan, owner, commands, changes)
    apply_emails(plan, owner, commands, changes)
    apply_when(plan, owner, commands, changes)
  end

  def self.apply_who(plan, owner, commands, changes)
    if commands[COMMAND_WHO]
      #MES- Invite each person in the WHO list to the plan (if they're not there already)
      commands[COMMAND_WHO].each do | email_address |
        #MES- If the email address is Skobee, do NOT make a user!
        if EmailId.remove_plus_from_email_address(email_address) != (UserSystem::CONFIG[:email_from_user] + UserSystem::CONFIG[:email_from_server])
          usr, created = User::find_or_create_from_email(email_address, owner)
          if !usr.nil?
            #MES- Don't notify this user of changes to the plan- they already got an email from the sender!
            plan.do_not_notify(usr)
            cal_to_add = usr.planner
            if !cal_to_add.nil?
              cals = plan.planners
              if !cals.include?(cal_to_add)
                cal_to_add.add_plan(plan)
                record_who_change(changes, usr, CHANGES_WHO_INVITED, created)
              end
            end
          end
        end
      end
    end
  end

  def self.apply_what(plan, owner, commands, changes)
    if (CHANGES_ACTION_CREATE_PLAN == changes[CHANGES_ACTION])
      #MES- When we're making a NEW plan, the 'what' can some from a what command,
      # OR from the subject.  Preference is given to the what command
      what_val = commands[COMMAND_WHAT] || commands[COMMAND_WHAT_SUBJECT]
      if !what_val.nil?
        plan.name = what_val
        changes[CHANGES_WHAT] = what_val
      end
    else
      #MES- For existing plans, we do NOT want to treat the subject as a what command
      if commands[COMMAND_WHAT]
        plan.name = commands[COMMAND_WHAT]
        changes[CHANGES_WHAT] = commands[COMMAND_WHAT]        
      end
    end
  end

  def self.apply_where(plan, owner, commands, changes)
    where = commands[COMMAND_WHERE]
    address = commands[COMMAND_ADDRESS]
    if !where.nil? || !address.nil?
      #MES- NOTE: Place names are NOT required to be unique, so this COULD
      # be non-deterministic.
      place, created = Place.find_or_create_by_name_and_location(where, address, owner)

      #MES- Now apply the place to the plan
      plan.place = place
      #MES- And record the change
      changes[CHANGES_WHERE] = [place, created]
    end
  end

  def self.apply_owner(plan, owner, commands, changes)
    if commands[COMMAND_OWNER]
      #MES- The OWNER is the user who created the email
      #MES- Find the user cal
      cal_to_add = owner.planner
      #MES- If the plan is new, we add this user as the owner
      cals = plan.planners
      if CHANGES_ACTION_CREATE_PLAN == changes[CHANGES_ACTION]
        cal_to_add.accept_plan(plan, nil, Plan::OWNERSHIP_OWNER)
        #MES- NOTE: A user CANNOT reject a plan that they are creating- if they
        # create it, they're in!
        record_who_change(changes, owner, CHANGES_WHO_OWNER, false)
      else
        #MES- This is NOT a new plan, so the plan already HAS an owner.
        # Did they reject the plan?
        if commands[COMMAND_REJECT]
          cal_to_add.reject_plan(plan)
          record_who_change(changes, owner, CHANGES_WHO_REJECTED, false)
        elsif commands[COMMAND_INTERESTED]
          cal_to_add.accept_plan(plan, nil, nil, Plan::STATUS_INTERESTED)
          record_who_change(changes, owner, CHANGES_WHO_INTERESTED, false)
        else
          cal_to_add.accept_plan(plan, nil)
          record_who_change(changes, owner, CHANGES_WHO_ACCEPTED, false)
        end
      end
    end
  end

  def self.apply_emails(plan, owner, commands, changes)
    arg = commands[COMMAND_EMAILS]
    email_ids_added = []
    if !arg.nil?
      #MES- Make sure that the plan has a record of each of the email_ids
      arg.each do | email_info |
        #MES- Is there already an EmailID object that describes the email?
        if !plan.email_ids.detect{ | existing_obj | existing_obj.email_id == email_info[0] }
          #MES- The item isn't there, add it
          plan.email_ids.create(:email_id => email_info[0], :canonical_subject => email_info[1])
          email_ids_added << email_info
        end
      end
    end

    #MES- Record any changes
    if !email_ids_added.empty?
      changes[CHANGES_EMAIL_IDS] = email_ids_added
    end
  end

  def self.apply_when(plan, owner, commands, changes)
    arg = commands[COMMAND_WHEN]
    if !arg.nil?
      exact_string_match_lookup = self.perform_datetime_exact_string_match(arg, plan)

      if !exact_string_match_lookup.nil?
        #MES- We got a hit!  Set the info
        plan.set_datetime owner.tz, exact_string_match_lookup[0], exact_string_match_lookup[1]
        #MES- Record the change
        changes[CHANGES_WHEN] = [owner.tz, exact_string_match_lookup[0], exact_string_match_lookup[1]]
        return
      end

      #MES- No exact string match, let's try some other stuff
      fully_specified_datetime_match_lookup = self.perform_fully_specified_datetime_match(arg, plan)
      date_arr, time_arr = nil, nil
      if !fully_specified_datetime_match_lookup.nil?
        #MES- We got a hit!
        date_arr = fully_specified_datetime_match_lookup[0]
        time_arr = fully_specified_datetime_match_lookup[1]
      end

      #MES- If we weren't able to completely understand the string, maybe Ruby can?
      if date_arr.nil? || time_arr.nil?
        parse_result = ParseDate.parsedate(arg)
        #MES- Did we get date info and do we need it?
        if date_arr.nil? && !parse_result[0].nil? && !parse_result[1].nil? && !parse_result[2].nil?
          date_arr = [parse_result[0], parse_result[1], parse_result[2]]
        end
        #MES- Did we get time info and do we need it?  Note that we don't look for second info
        if time_arr.nil? && !parse_result[3].nil? && !parse_result[4].nil?
          time_arr = [parse_result[3], parse_result[4], 0]
        end
      end

      #MES- Did we get anything?
      if !date_arr.nil? || !time_arr.nil?
        plan.set_datetime owner.tz, date_arr, time_arr
        #MES- Record the change
        changes[CHANGES_WHEN] = [owner.tz, date_arr, time_arr]
        return
      end

      #MES- We weren't able to understand the string, set a default value
      plan.set_datetime owner.tz, Plan::DEFAULT_DATE, Plan::DEFAULT_TIME
      #MES- Record the change
      changes[CHANGES_WHEN] = [owner.tz, Plan::DEFAULT_DATE, Plan::DEFAULT_TIME]

      #MES- We can't interpret this string!  Don't set the time.
      logger.info "Failure in Mailman::apply_when, unable to interpret datetime string '#{arg}'"
#MES- TODO: Record the failure into the plan, so users can see what the other user
# attempted to do?
    else
      #MES- No time was supplied.  If this is a NEW plan, we should set it do the default time.
      if plan.new_record?
        plan.set_datetime owner.tz, Plan::DEFAULT_DATE, Plan::DEFAULT_TIME
      end
    end
  end

  def self.record_who_change(changes, user, change, created_user)
    #MES- Make sure we have a place to put the change
    if !changes.has_key?(CHANGES_WHO)
      changes[CHANGES_WHO] = []
    end

    #MES- Add the change
    changes[CHANGES_WHO] << [user, change, created_user]
  end



##########################################################
####### Date parsing/handling functions
##########################################################

  def self.perform_datetime_exact_string_match(to_lookup, plan)
    #MES- Normalize the case, trim, and remove punctuation
    to_lookup = to_lookup.downcase.strip.delete('^a-z0-9 ')

    #MES- Perform the lookup
    res = self.get_exact_matches_map[to_lookup]

    #MES- Did we find anything?
    return nil if res.nil?

    #MES- Translate the entries, as needed
    return [self.translate_date_constant(res[0], plan), self.translate_time_constant(res[1], plan)]
  end

  def self.translate_date_constant(const, plan)
    #MES- If nothing was passed in, we're done
    return nil if const.nil?

    #MES- Is it a constant that Plan can understand?
    return const if const < Plan::DATE_DESCRIPTION_INVALID

    #MES- Nope, it's one of ours
    today = Date.today
    case const
      when DATE_DESCRIPTION_MON
        return today.next_weekday(1).to_numeric_arr
      when DATE_DESCRIPTION_TUES
        return today.next_weekday(2).to_numeric_arr
      when DATE_DESCRIPTION_WED
        return today.next_weekday(3).to_numeric_arr
      when DATE_DESCRIPTION_THURS
        return today.next_weekday(4).to_numeric_arr
      when DATE_DESCRIPTION_FRI
        return today.next_weekday(5).to_numeric_arr
      when DATE_DESCRIPTION_SAT
        return today.next_weekday(6).to_numeric_arr
      when DATE_DESCRIPTION_SUN
        return today.next_weekday(0).to_numeric_arr

      #MES- NOTE: The rule for "next Xday" is to choose day X in the next
      # week.  For example, if today is Wednesday, then "Next Thursday"
      # is in 8 days.  A funny case is when today is Sunday.  Then
      # Next Monday is tomorrow.  See ticket #476.
      when DATE_DESCRIPTION_NEXT_MON
        return (today.last_day_of_week.next_weekday(1)).to_numeric_arr
      when DATE_DESCRIPTION_NEXT_TUES
        return (today.last_day_of_week.next_weekday(2)).to_numeric_arr
      when DATE_DESCRIPTION_NEXT_WED
        return (today.last_day_of_week.next_weekday(3)).to_numeric_arr
      when DATE_DESCRIPTION_NEXT_THURS
        return (today.last_day_of_week.next_weekday(4)).to_numeric_arr
      when DATE_DESCRIPTION_NEXT_FRI
        return (today.last_day_of_week.next_weekday(5)).to_numeric_arr
      when DATE_DESCRIPTION_NEXT_SAT
        return (today.last_day_of_week.next_weekday(6)).to_numeric_arr
      when DATE_DESCRIPTION_NEXT_SUN
        return (today.last_day_of_week.next_weekday(0)).to_numeric_arr
      when DATE_DESCRIPTION_NOT_SPECIFIED
        #MES- The user didn't specify a date.
        if plan.new_record?
          #MES- This is a NEW plan, return the default date
          return Plan::DEFAULT_DATE
        else
          #MES- It's an existing plan, we want to NOT overwrite any existing date
          return nil
        end
    end
  end

  def self.translate_time_constant(const, plan)
    #MES- If nothing was passed in, we're done
    return nil if const.nil?

    #MES- Is it a constant that Plan can understand?
    return const if const < Plan::TIME_DESCRIPTION_INVALID

    #MES- It's one of ours
    case const
      when TIME_DESCRIPTION_NOT_SPECIFIED
        #MES- The user didn't specify a time
        if plan.new_record?
          #MES- This is a NEW plan, return the default time
          return Plan::DEFAULT_TIME
        else
          #MES- It's an existing plan, do NOT overwrite any existing time
          return nil
        end
    end
  end


  def self.perform_fully_specified_datetime_match(datetime_str, plan)
    #MES- Look for a time and/or a date in the string using Regex's

    #MES- Normalize the case, trim, and remove punctuation
    datetime_str = datetime_str.downcase.strip.delete('^a-z0-9:/\- ')
    time_info = nil
    date_info = nil

    #MES- Look for a time in the string
    hour, minute, meridian, remainder = self.find_fully_specified_time(datetime_str)

    #MES- Did we find a time?
    if !hour.nil?
      #MES- We found time, convert the meridian stuff to a real hour and minute
      hour = Time::correct_hour_for_meridian(hour, meridian)
      time_info = [hour, minute, 0]

      #MES- Deal with the remainder of the string.  It might be an exact match
      # string (such as "Tomorrow"), or it might be a date (such as '12/15/2005')
      if !remainder.nil? && !remainder.empty?
        remainder.strip!

        #MES- Look for an exact string match
        lookup = self.get_exact_date_matches_map[remainder]
        if !lookup.nil?
          date_info = self.translate_date_constant(lookup, plan)
        else
          #MES- No exact string match, is the date a fully specified date (e.g. 12/17/2005)?
          year, month, day, remainder2 = self.find_fully_specified_date(remainder)
          if !day.nil?
            date_info = [year, month, day]
          end
        end
      end
    end

    #MES- Did we find the time info?  If so, we're done
    if !time_info.nil?
      return date_info, time_info
    end

    #MES- We've looked for fully specified times, and then exact or fully specified dates.
    # One case remains- a fully specified date and an exact match time
    year, month, day, remainder = self.find_fully_specified_date(datetime_str)
    if !year.nil?
      date_info = [year, month, day]

      #MES- Look for an exact match for the time string.  We do NOT need to look for a
      # fully specified match, since we've already checked that case
      if !remainder.nil? && !remainder.empty?
        remainder.strip!
        lookup = self.get_exact_time_matches_map[remainder]
        if !lookup.nil?
          time_info = self.translate_time_constant(lookup, plan)
        end
      end
    end

    #MES- Return whatever we got
    return date_info, time_info
  end

  def self.find_fully_specified_time(str)
    #MES- Match based on a regex.  Look for a time at the beginning of the string.
    md = str.match('^([01]?\d)(:([0-5]\d))? ?([ap]m)( .*)?')
    if !md.nil?
      minute = (md[3].nil? ? 0 : md[3].to_i)
      return md[1].to_i, minute, md[4], md[5]
    end

    #MES- If we didn't find it, look for the time at the end of the string
    md = str.match('^(.* )?(([01]?\d)(:([0-5]\d))? ?([ap]m))$')
    if !md.nil?
      minute = (md[5].nil? ? 0 : md[5].to_i)
      return md[3].to_i, minute, md[6], md[1]
    end

    #MES- We didn't find it
    return nil
  end

  def self.find_fully_specified_date(str)
    #MES- Match based on a regex.  Look for a date (in the format mm/dd/yyyy or
    # mm/dd/yyyy) at the beginning of the string
    md = str.match('^(0?[1-9]|1[012])[-/.](0?[1-9]|[12][0-9]|3[01])([-/.]((19|20)?\d\d))?( .*)?$')
    if !md.nil?
      #MES- Return year, month, day, remainder
      return correct_year(md[4].to_i), md[1].to_i, md[2].to_i, md[6]
    end

    #MES- It wasn't at the beginning of the string, is it at the end?
    md = str.match('^(.* )?(0?[1-9]|1[012])[-/.](0?[1-9]|[12][0-9]|3[01])([-/.]((19|20)?\d\d))?$')
    if !md.nil?
      #MES- Return year, month, day, remainder
      return correct_year(md[5].to_i), md[2].to_i, md[3].to_i, md[1]
    end

    return nil
  end

  def self.correct_year(original_year)
    #MES- If the year is 0, the user didn't specify the year, use the current
    # year as the default
    return Date.today.year if 0 == original_year

    #MES- Handle two digit years- if the year is less than 100, add 2000
    return 2000 + original_year if original_year < 100

    return original_year
  end


  @@exact_matches_map = nil
  def self.get_exact_matches_map
    if @@exact_matches_map.nil?
      date_arr = self.get_date_string_array
      time_arr = self.get_time_string_array

      #MES- We want to make a string map that maps
      # each combination of date and time string (and
      # the reverse- time and date string) to the
      # relevant date and time constants.
      emm = {}
      date_arr.each do | date_entry |
        time_arr.each do | time_entry |
          datetime = "#{date_entry[1]} #{time_entry[1]}".strip
          emm[datetime] = [date_entry[0], time_entry[0]]
          timedate = "#{time_entry[1]} #{date_entry[1]}".strip
          emm[timedate] = [date_entry[0], time_entry[0]]
        end
      end

      #MES- Trim out the empty entry, if there is one
      emm.delete ''

      #MES- Add an entry for "to be decided"
      emm['tbd'] = [Plan::DATE_DESCRIPTION_FUTURE, Plan::TIME_DESCRIPTION_ALL_DAY]

      @@exact_matches_map = emm
    end

    return @@exact_matches_map
  end

  @@exact_date_matches_map = nil
  def self.get_exact_date_matches_map
    if @@exact_date_matches_map.nil?
      date_arr = self.get_date_string_array
      emm = {}
      date_arr.each do | date_entry |
        #MES- Make an entry for the date
       emm[date_entry[1]] = date_entry[0]
      end

      @@exact_date_matches_map = emm
    end

    return @@exact_date_matches_map
  end

  @@exact_time_matches_map = nil
  def self.get_exact_time_matches_map
    if @@exact_time_matches_map.nil?
      time_arr = self.get_time_string_array
      emm = {}
      time_arr.each do | time_entry |
        emm[time_entry[1]] = time_entry[0]
      end

      @@exact_time_matches_map = emm
    end

    return @@exact_time_matches_map
  end

  #MES- Supplement the date descriptions in Plan with some that are
  # specific to us
  DATE_DESCRIPTION_MON = 1000
  DATE_DESCRIPTION_TUES = 1001
  DATE_DESCRIPTION_WED = 1002
  DATE_DESCRIPTION_THURS = 1003
  DATE_DESCRIPTION_FRI = 1004
  DATE_DESCRIPTION_SAT = 1005
  DATE_DESCRIPTION_SUN = 1006
  DATE_DESCRIPTION_NEXT_MON = 1007
  DATE_DESCRIPTION_NEXT_TUES = 1008
  DATE_DESCRIPTION_NEXT_WED = 1009
  DATE_DESCRIPTION_NEXT_THURS = 1010
  DATE_DESCRIPTION_NEXT_FRI = 1011
  DATE_DESCRIPTION_NEXT_SAT = 1012
  DATE_DESCRIPTION_NEXT_SUN = 1013
  DATE_DESCRIPTION_NOT_SPECIFIED = 1014

  @@date_string_arr = nil
  def self.get_date_string_array
    if @@date_string_arr.nil?
      #MES- Grab the date descriptions from Plan::DATE_DESCRIPTIONS and
      # convert the strings to lower case
      dsa = Plan::DATE_DESCRIPTIONS.to_a.collect { | entry | [entry[0], entry[1].downcase]}

      #MES- Add entries for our special descriptions
      dsa << [DATE_DESCRIPTION_MON, 'monday']
      dsa << [DATE_DESCRIPTION_MON, 'mon']
      dsa << [DATE_DESCRIPTION_TUES, 'tuesday']
      dsa << [DATE_DESCRIPTION_TUES, 'tues']
      dsa << [DATE_DESCRIPTION_WED, 'wednesday']
      dsa << [DATE_DESCRIPTION_WED, 'wed']
      dsa << [DATE_DESCRIPTION_THURS, 'thursday']
      dsa << [DATE_DESCRIPTION_THURS, 'thur']
      dsa << [DATE_DESCRIPTION_FRI, 'friday']
      dsa << [DATE_DESCRIPTION_FRI, 'fri']
      dsa << [DATE_DESCRIPTION_SAT, 'saturday']
      dsa << [DATE_DESCRIPTION_SAT, 'sat']
      dsa << [DATE_DESCRIPTION_SUN, 'sunday']
      dsa << [DATE_DESCRIPTION_SUN, 'sun']
      dsa << [DATE_DESCRIPTION_NEXT_MON, 'next monday']
      dsa << [DATE_DESCRIPTION_NEXT_MON, 'next mon']
      dsa << [DATE_DESCRIPTION_NEXT_TUES, 'next tuesday']
      dsa << [DATE_DESCRIPTION_NEXT_TUES, 'next tues']
      dsa << [DATE_DESCRIPTION_NEXT_WED, 'next wednesday']
      dsa << [DATE_DESCRIPTION_NEXT_WED, 'next wed']
      dsa << [DATE_DESCRIPTION_NEXT_THURS, 'next thursday']
      dsa << [DATE_DESCRIPTION_NEXT_THURS, 'next thur']
      dsa << [DATE_DESCRIPTION_NEXT_FRI, 'next friday']
      dsa << [DATE_DESCRIPTION_NEXT_FRI, 'next fri']
      dsa << [DATE_DESCRIPTION_NEXT_SAT, 'next saturday']
      dsa << [DATE_DESCRIPTION_NEXT_SAT, 'next sat']
      dsa << [DATE_DESCRIPTION_NEXT_SUN, 'next sunday']
      dsa << [DATE_DESCRIPTION_NEXT_SUN, 'next sun']
      dsa << [Plan::DATE_DESCRIPTION_THIS_WEEKEND, 'this weekend']
      dsa << [Plan::DATE_DESCRIPTION_NEXT_WEEKEND, 'next weekend']
      dsa << [Plan::DATE_DESCRIPTION_THIS_WEEK, 'this week']
      dsa << [Plan::DATE_DESCRIPTION_NEXT_WEEK, 'next week']
      dsa << [DATE_DESCRIPTION_NOT_SPECIFIED, '']

      @@date_string_arr = dsa
    end

    return @@date_string_arr
  end


  #MES- Supplement the time descriptions
  TIME_DESCRIPTION_NOT_SPECIFIED = 2000

  @@time_string_arr = nil
  def self.get_time_string_array
    if @@time_string_arr.nil?
      #MES- Grab the time descriptions from Plan::TIME_DESC_TO_ENGLISH and
      # convert the strings to lower case
      tsa = Plan::TIME_DESC_TO_ENGLISH.collect { | entry | [entry[0], entry[1].downcase]}

      #MES- Add entries for our special descriptions/synonyms
      tsa << [Plan::TIME_DESCRIPTION_EVENING, 'eve']
      tsa << [Plan::TIME_DESCRIPTION_EVENING, 'night']
      tsa << [Plan::TIME_DESCRIPTION_DINNER, 'din']
      tsa << [Plan::TIME_DESCRIPTION_AFTERNOON, 'midday']
      tsa << [TIME_DESCRIPTION_NOT_SPECIFIED, '']

      @@time_string_arr = tsa
    end

    return @@time_string_arr
  end





##########################################################
####### Email parsing functions
##########################################################



  def self.parse_email(email)
    #MES- Take an email, and parse it into a list of commands.
    # The commands indicate which plan attribute to affect (e.g. "what")
    # and how to affect it (i.e. the new value.)
    # The result is a hash with a COMMAND_XXX constant as the key, and a
    # string as the value.

    #MES- Is there a regexp we should use to figure out if we're done
    # parsing the email?  If so, pass it into parse_body.
    result = parse_body(email.plaintext_body, stop_on_regexp(email))

    #MES- Get a possible "what" from the subject
    if !email.subject.nil? && !email.subject.empty?
      result[COMMAND_WHAT_SUBJECT] = email.subject
    end

    #MES- If the result doesn't include a "who" method, then use the
    # relevant fields as the who
    if !result.include?(COMMAND_WHO)
      result[COMMAND_WHO] = who_from_email_headers(email)
    end

    #MES- The owner is the person who sent the email (this won't be
    # used when the email edits an existing plan.)
    result[COMMAND_OWNER], result[COMMAND_OWNER_NAME] = owner_from_email_headers(email)

    #MES- Get the associated email IDs
    result[COMMAND_EMAILS] = identification_array_from_email(email)

    return result
  end

  def self.stop_on_regexp(email)
    #MES- This function figures out if parsing of the email should terminate when
    # a line in the email does NOT correspond to a command.
    # In general, we'd like to parse the whole email, so that an email like this would
    # be understood:
    #
    #   Hey guys, how about this time?
    #   when: 8 PM
    #
    #   > where: Pancho's Mexican Restaurant
    #   > when: dinner next thursday
    #
    # The problem is that some email clients may not separate the email body and any email
    # that is being responded to.  For example, if the email looks like this, we have
    # a problem:
    #
    #   Hey guys, how about this time?
    #   when: 8 PM
    #
    #   ________________________________________
    #   From: Michael Smedberg [mailto:smedberg@gmail.com]
    #   Sent: Wednesday, December 28, 2005 2:08 PM
    #   To: michaels@skobee.com
    #   Subject: test2
    #
    #   where: Pancho's Mexican Restaurant
    #   when: dinner next thursday
    #
    # In this case, we do NOT want to use the SECOND 'when', since it's part of the PREVIOUS
    # email.  We can't tell where the current email ends and the previous email begins, so
    # we can't definitively tell which commands should be applied.
    #
    # In particular, Outlook seems to do this.  You can detect that an email was sent by
    # Outlook by looking for the X-Mailer header (which has the value of 'Microsoft Office Outlook 11'
    # for Outlook 2003.)  But not all client include an X-Mailer header (gmail and yahoo seem not
    # to do so), so it's not reliable.
    #


    #MES- If this email is not a reply, then we don't need to worry about this garbage.
    # We can't tell if emails from Exchange are replies or not, so for Exchange we'll
    # always do the full meal deal.
    from_exch = email.from_exchange?
    if email.in_reply_to.nil? && !from_exch
      return nil
    end

    #MES- NOTE: We check for thick clients (via headers like X-Mailer or User-Agent) before
    # checking for thin clients (by looking at the domain of the FROM email address.)
    # This is because a thick client might be used to front-end an online email server (e.g.
    # you might use Thunderbird as the UI for gmail.)  In this case, the thick client is
    # composing the email, so the thick client is the thing that determines the format
    # of the email body.

    #MES- For Outlook, we want to check the the X-MimeOLE header
    if from_exch
      #MES- Outlook does not indent the original email, but does separate the reply
      # from the original with a section of text that includes things like 'From: ',
      # 'Sent: ', 'To: ', and 'Subject: '
      return Regexp.new('From: ')
    end

    #MES- For Thunderbird, we want to check the User-Agent header
    useragent = email['User-Agent']
    if !useragent.nil?
      if useragent.to_s.match('Thunderbird')
        #MES- Thunderbird is similar to Gmail (i.e. it preceeds the original email with '>'.
        # However, when you reply to an email, it places the cursor UNDER the info about
        # the original email.  This makes it much more likely that the user will put commands
        # at the very end of the email.  To compensate, we must parse the whole email.
        return nil
      end
    end

    #MES- Web based email client generally indent the email that is being replied to.
    # In this case, no regexp is needed- we can just process the whole email.
    from_address = owner_from_email_headers(email)[0]
    domain_match = from_address.match('.*@(.*)$')
    if !domain_match.nil?
      domain = domain_match[1]
      #MES- Is the domain of the 'from' address recognized?
      case domain
      when 'hotmail.com'
        #MES- Hotmail allows users to choose prefix the reply with '>' or not, and whether there should
        # be a horizontal separator.  In any case, the original email starts with the string 'From: '
        # or '>From: '
        return Regexp.new('^>?From: ')
      when 'gmail.com'
        #MES- Gmail preceeds the original email with '>'
        return nil
        #return Regexp.new('^>')
      when 'yahoo.com'
        #MES- Yahoo preceeds the original email with '  ' (two spaces)
        return nil
        #return Regexp.new('^  ')
      end
    end

    #MES- The default case, return a regex that ALWAYS passes.  This
    # means that any line matches, which in turn means that parsing the
    # email will be abandoned when any non-command line is seen.
    return Regexp.new('.*')
  end

  def self.parse_body(body, stop_on_regexp)
    #MES- Parses the body of an email, and returns a map of the results.
    # The keys in the map are COMMAND_XXX constants, and the values are the
    # corresponding strings.

    result = {}
    #MES- If we can't get the body, we can't do much, but at least we can
    # create a plan based on the subject and the TO and CC lists.
    if !body.nil?
      body.each do | line |
        line.chomp!
        #MES- Iterate through all the method identifiers, looking for one that matches the current line
        matched = false
        COMMAND_IDENTIFIERS.each do | meth_id |
          match = meth_id[0].match(line)
          if !match.nil?
            #MES- This is a match
            #MES- Should we extract an argument?
            arg = true
            if !meth_id[1].nil?
              arg = match[meth_id[1]]
            end
            method = meth_id[2]
            #MES- Have we seen this method before?  If so, we're probably done.
            if result.include?(method)
              #MES- We HAVE seen this method before- we've probably walked off
              # the end of any method specifications- we might be in lines that
              # were in a previous email (i.e. THIS email is a reply, but the
              # ORIGINAL email also included some methods, one of which is a dup.)
              return result
            end
            #MES- We haven't seen it before, we want to record this
            result[method] = arg
            matched = true
            #MES- Break out of the loop- we've already found a match
            break
          end
        end

        #MES- If we did NOT find a match, and the current line is NOT blank, then
        # we may be done.  The stop_on_regexp argument tells us
        # what to look for in the current line to know that we should stop
        # processing.  If it's nil, we just process the whole email.
        if !matched && !line.strip.empty? && !stop_on_regexp.nil?
          #MES- Does the current line match the regexp?  If so, we should quit.
          match = stop_on_regexp.match(line)
          if (!match.nil?)
            return result
          end
        end
      end
    end

    #MES- We've run through all of the lines in the email, and we're all done!
    return result
  end

  def self.who_from_email_headers(email)
    #MES- Returns an array of the email addresses from the email
    result = []
    result.concat emails(email.to_addrs)
    result.concat emails(email.cc_addrs)
    #MES- NOTE: We do NOT include bccs- a bcc'd user will NOT be included.
    # This seems sensible, though I can't necessarily make a cogent argument for it.

    return result.uniq
  end

  #MES- Takes in an email, returns an array of info about the sender.
  # The first item is the email address of the sender, the second is the
  # "real" name of the user (based on the email headers.)
  def self.owner_from_email_headers(email)
    #MES- According the the TMail doc, the from address is an array of emails,
    # which implies it might contain more than one value.  This is pretty weird,
    # and we don't support it.
    if 1 != email.from_addrs.length
#MES- TODO: Should we create and store a Feedback object here?
      logger.error("Error in Mailman::owner_from_email_headers, count of from_addrs is not 1.  It is #{email.from_addrs.length}")
    end
    return [email.from_addrs[0].spec, email.from_addrs[0].phrase]
  end

  def self.emails(email_list)
    #MES- Retrieve the email addresses from email_list, return as an array
    result = []
    if !email_list.nil?
      email_list.each do | to_addr |
        if to_addr.address_group?
          to_addr.each_address do | sub_addr |
            #MES- Do NOT add RECEIVE_MAIL_ADDRESS or any derivative thereof
            if !sub_addr.spec.match(/.*#{RECEIVE_MAIL_ADDRESS}/)
              result << sub_addr.spec
            end
          end
        else
          #MES- Do NOT add RECEIVE_MAIL_ADDRESS or any derivative thereof
          if !to_addr.spec.match(/.*#{RECEIVE_MAIL_ADDRESS}/)
            result << to_addr.spec
          end
        end
      end
    end

    return result
  end

  def self.identification_array_from_email(email)
    #MES- Retrieve the email IDs associated with this email.  This includes
    # the ID of THIS email, as well as the ID of emails that this is a response to.
    # NOTE: We're not talking about email addresses of users, we're talking about the
    # actual ID of the email itself (this is not something that users are ever exposed to.)
    # Additionally, retrieve the canonical subject of the email.  Subjects are used as a
    # fallback for identifying emails when the IDs are unavailable
    result = []

    #MES- Include the id of THIS email
    result << [email.message_id, EmailId.canonicalize_subject(email.subject)]

    #MES- Include the id of all "reply to" emails
    if !email.in_reply_to.nil?
      email.in_reply_to.each { | reply_to_id | result << [reply_to_id, nil] }
    end

    #MES- Include the id of all "reference" emails
    if !email.references.nil?
      email.references.each { | reference_id | result << [reference_id, nil] }
    end

    return result
  end

  #MES- Send a pingback- someone sent us an email asking how things are going, tell them.
  def perform_pingback(email)
    #MES- Who sent the email?
    user_info = Mailman.owner_from_email_headers(email)
    #MES- Reply in kind
    UserNotify.deliver_mailman_pingback(user_info, email, @@num_received, @@num_successfully_processed)
  end





##########################################################
####### Agent logic
##########################################################

  def self.receive_emails
    Net::POP3.start(RECEIVE_MAIL_SERVER, nil, RECEIVE_MAIL_USER, RECEIVE_MAIL_PASSWORD) do | pop |
      if !pop.mails.empty?
        pop.each_mail do | mail_item |
          puts 'Receiving email'
          mail_contents = mail_item.pop
          begin
            Mailman.receive mail_contents
          rescue Exception => exc
            puts "Exception when receiving mail: #{exc}"
            puts exc.backtrace.join("\n")
          end
          mail_item.delete
        end
      end
    end
  end

  def self.receive_emails_loop
    begin
      loop do
        self.receive_emails
        sleep 1
      end
    rescue Interrupt
    end
  end

  def self.receive_emails_from_files(receive_folder, handled_folder, file_pattern = EMAIL_FILE_PATTERN)
    #MES- Find files that match file_pattern in the receive_folder directory.
    # These files contain emails that we should process.
    # We parse the email, create or alter plans as necessary,
    # and copy the file to handled_folder.
    shutdown_file_name = File.join([receive_folder, 'shutdown'])
    begin
      loop do
        #MES- Are we supposed to shutdown?  If so, there'll be a file called "shutdown" in the
        # receive folder.
        if File.exists?(shutdown_file_name)
          puts "Shutting down email receiver due to existence of #{shutdown_file_name} file."
          begin
            File::delete shutdown_file_name
          rescue Exception => exc
            #MES- Report errors on deleting shutdown file
            puts "Error deleting shutdown file #{shutdown_file_name}: #{exc}"
          end
          return 0
        end

        #MES- Call the helper to parse the files that are there right now.
        files_handled = self.receive_emails_from_files_noloop(receive_folder, handled_folder, file_pattern)


        #MES- If there were no files, sleep a bit.  If there WERE files, keep chugging
        if (0 >= files_handled)
          sleep EMAIL_RECEIVE_SLEEP_SECS

          #MES- Re-establish the DB connection if it is stale
          #MES- TODO: Centralize this code?  Might we want it in other long-running processes?
          conn = Plan.connection
          error_count = 0
          while !conn.active?
            #MES- Try reconnecting to the DB
            begin
              conn.reconnect!
            rescue Exception => exc
              #MES- An error connecting, wait a bit and see if the DB comes back
              puts "Error in Mailman::receive_emails_from_files when connecting to DB:"
              puts exc
              error_count = error_count + 1
              if EMAIL_DB_CONNECT_ERROR_LIMIT < error_count
                puts "Over #{EMAIL_DB_CONNECT_ERROR_LIMIT} errors detected when trying to connect to the DB- exiting"
                return 1
              end
              sleep EMAIL_DB_CONNECT_ERROR_SLEEP_SECS
            end
          end

        end
      end
    rescue Interrupt
    end
  end

  def self.receive_emails_from_files_noloop(receive_folder, handled_folder, file_pattern)
    #MES- Find files in the RECEIVE_MAIL_FOLDER directory.
    # These files contain emails that we should process.
    # Return the number of emails processed

    #MES- Find the files, and receive each one
    files = findfiles(receive_folder, file_pattern)

    #MES- Process any files (if there are none, this is a no-op)
    res = 0
    files.each do | filename |
      res = res + receive_email_from_file(filename, handled_folder)
    end

    return res
  end

  def self.receive_email_from_file(filename, handled_folder)
    #MES- Grab the file so that other instances of this process don't try to
    # process the file.  Locking the file might be good, but locking behavior
    # is platform dependent.  To get around this, and for ease of programming,
    # we'll just rename the file.  In the future, we might want to switch to
    # locking or some other more sophisticated method of gaining exclusive access
    # to the file, but this should do for now.
    # The return value is the number of emails processed (normally 1, 0 in case of error, etc.)
    nameparts = File.split(filename)
    processing_file_name = File.join([nameparts[0], EMAIL_FILE_PROCESSING_PREFIX + nameparts[1]])
    processed_file_name = File.join([handled_folder, nameparts[1]])

    begin
      processing_file_name = rename_file_safe(filename, processing_file_name)
    rescue SystemCallError => error_obj
      #MES- The file could not be renamed, probably another
      # process has already started processing the file?  I.e.
      # another process (or thread) has already renamed the file?
      logger.info("In Mailman::receive_email_from_file, unable to rename file #{filename} to #{processing_file_name}: #{error_obj}")
      #MES- We couldn't process the email, return 0
      return 0
    end

    #MES- Now we want to process the processing_file_name file
    begin
      #MES- Read the file
      raw_email = IO.read(processing_file_name)
      #MES- And process it
      Mailman.receive raw_email
    rescue Exception => exc
      error_file_name = File.join([handled_folder, EMAIL_FILE_ERROR_PREFIX + nameparts[1]])
      logger.info("An error occurred while processing file #{processing_file_name} (which will be copied to #{processed_file_name}):\n #{exc}")
      #MES- Note: an error could occur while writing this file.  In that case, we'll
      # exit this function with an error (we don't handle it.)
      open(error_file_name, 'w+') do | file |
        if !file.nil?
          file.puts "An error occurred while processing file #{processing_file_name} (which will be copied to #{processed_file_name}):"
          file.puts exc.to_s
          file.puts "Stack backtrace:"
          file.puts exc.backtrace.join("\n")
        end
      end
    ensure
      #MES- Regardless of success or failure, we want to move the file
      # to the "processed" location.
      begin
        processed_file_name = rename_file_safe(processing_file_name, processed_file_name)
      rescue SystemCallError => error_obj
        #MES- The file could not be renamed, probably another
        # process has already started processing the file?  I.e.
        # another process (or thread) has already renamed the file?
        logger.info("In Mailman::receive_email_from_file, unable to rename processing file #{filename} to processed file #{processing_file_name}: #{error_obj}")
      end
    end

    #MES- We processed the email (one way or another), return 1
    return 1
  end

  def self.rename_file_safe(original_name, proposed_new_name)
    #MES- Rename file original_name to proposed_new_name, if there is not already
    # a file by that name.  If there is, try to come up with an alternate name
    # that isn't taken
    newname = proposed_new_name.clone
    tries = 0
    while File.exists?(newname) && tries < 100 do
      newname = proposed_new_name + '.' + rand(99999).to_s
      tries += 1
    end

    #MES- Did we make a bunch of tries and fail to find an untaken name?  This
    # is almost certainly a bug in our code somewhere.
    if 100 == tries
      raise "Error in Mailman::rename_file_safe, could not find new name for #{proposed_new_name} that doesn't already exist"
    end

    #MES- There's a very tiny chance that another process has created
    # a file called newname between the time we called File.exists? and now,
    # but that's very remote.  Also, our rename will still succeed- File.rename
    # replaces existing files without warning.
    File.rename(original_name, newname)

    return newname
  end

  #MES- A utility for finding files, from "The Ruby Way" by Hal Fulton
  def self.findfiles(dir, name)
    list = []
    Find.find(dir) do | path |
      Find.prune if ['.', '..'].include? path
      case name
        when String
          list << path if File.basename(path) == name
        when Regexp
          list << path if File.basename(path) =~ name
        else
          raise ArgumentError
      end
    end
    list
  end

end
