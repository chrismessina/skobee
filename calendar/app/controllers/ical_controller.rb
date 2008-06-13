require 'date'
require 'vpim/icalendar'

class IcalController < ApplicationController
  #MGS- ical PARTSTATS per rfc
  PARTSTAT_ACCEPTED = "ACCEPTED"
  PARTSTAT_DECLINED = "DECLINED"
  PARTSTAT_TENTATIVE = "TENTATIVE"
  PARTSTAT_NEEDS_ACTION = "NEEDS-ACTION"

  #MGS- map of plan statuses to ICal partstats
  PLAN_STATUS_TO_PARTSTAT = {
    Plan::STATUS_INVITED => PARTSTAT_NEEDS_ACTION,
    Plan::STATUS_ACCEPTED => PARTSTAT_ACCEPTED,
    Plan::STATUS_REJECTED => PARTSTAT_DECLINED,
    Plan::STATUS_CANCELLED => PARTSTAT_DECLINED,    #MGS- this is arguable
    Plan::STATUS_INTERESTED => PARTSTAT_TENTATIVE   #MGS- let's face it, the interested status is a tentative accept
  }
  TRANSPARENCY_OPAQUE = "OPAQUE"

  def publish
    #MGS- get the planner id out of the qs
    if params[:id].nil?
      raise "No planner ID was passed on the querystring."
    else
      planner_id = params[:id]
    end

    #MGS- get the user_id out of the qs
    if params[:user_id].nil?
      raise "No user ID was passed on the querystring."
    else
      user_id = params[:user_id]
    end

    #MGS- get the key out of the qs
    if params[:ikey].nil?
      raise "No token was passed on the querystring."
    else
      ikey = params[:ikey]
    end

    user = User.find(user_id)
    tz = user.tz
    #MGS- generate the key that should be in the querystring
    # based on the other params passed.
    correct_hash = generate_ical_key(user, planner_id)

    #MGS- check that the key passed on the querystring, matches what the key should look like based on what
    # other parameters are passed in the qs.
    #MGS- always require the login token on the querystring, regardless of logged in status
    if correct_hash != ikey
      raise "The key passed on the ICal querystring doesn't match."
    end

    planner = Planner.find(params[:id])
    #MGS- get all plans past and future out of the planner
    #MGS- TODO, maybe we only display a month of history or so in the future?
    # This will become expensive for skobee power users.
    #MGS- don't add rejected or cancelled plans to the ical feed
    plans = planner.plans.select{ |pln| ![Plan::STATUS_CANCELLED, Plan::STATUS_REJECTED].include?(pln.cal_pln_status.to_i) }
    cal = Vpim::Icalendar.create({ "X-WR-CALNAME" => "#{Inflector.possessiveize(user.login)} Skobee Plans"})

    plans.each do | pln |
      #MGS- the vpim API is more robust for Vevents than Vtodos, but for
      # consistency, we make a fields hash and pass in the common values for
      # both events and todos here
      fields = {}
      #MGS- handle blank plan names
      fields['SUMMARY'] = pln.name.blank? ? "We've got plans" : pln.name
      fields['DESCRIPTION'] = pln.description if !pln.description.blank?
      #MGS- the sequence is # of time changes on the plan
      fields['SEQUENCE'] = get_sequence(pln).to_s
      #MGS- common date fields
      fields['DTSTAMP'] = Time.now
      fields['CREATED'] = pln.created_at
      fields['LAST-MODIFIED'] = pln.updated_at
      #MGS- the transparency should be OPAQUE for all Skobee events
      fields['TRANSP'] = TRANSPARENCY_OPAQUE
      #MGS- set the UID to the same deal we put in for RSS
      fields['UID'] = pln.guid
      fields['URL'] = url_for(:controller => 'plans', :action => 'show', :id => pln.id, :cal_id => pln.owner.id)

      #MGS- set the place
      place = pln.place
      if !place.nil?
        loc = ''
        loc << place.name unless place.name.blank?
        #MGS- add a spacer
        loc << " - " if !loc.blank? && !place.location.blank?
        #MGS- add the address to the location
        loc << place.location unless place.location.blank?
        #MGS- now add this built string to the VEVENT
        fields['LOCATION'] = loc
        fields['GEO'] = place.lat.to_s << ";" << place.long.to_s if place.location_is_physical_address?
      end

      #MGS- get the local start for the plan
      local_start = tz.utc_to_local(pln.start)

      if !pln.fuzzy?(current_timezone)
        #MGS- for solid plans, make an ICal event
        event = Vpim::Icalendar::Vevent.create(fields)

        case pln.timeperiod
          when Plan::TIME_DESCRIPTION_ALL_DAY
            #MGS- if the timeperiod for the plan, is an all day event only set the
            # dtstart/end as consecutive dates
            event.dtstart       local_start.to_date
            event.dtend         local_start.to_date + 1
          when Plan::TIME_DESCRIPTION_EVENING
            event.dtstart       local_start
            #MGS- since the duration of EVENING plans is 298 min, add a couple of minutes back
            event.dtend         local_start + ((pln.duration + 2) * 60)
          else
            #MGS- this is an event for an actual time, set the start time to the start time
            # and the end to the start time plus the duration of the plan in seconds
            event.dtstart       local_start
            event.dtend         local_start + (pln.duration * 60)
        end
      else
        #MGS- for fuzzy plans, make a Task
        event = Vpim::Icalendar::Vtodo.create(fields)
        #MGS- set the start/end times for the task
        event.dtstart local_start
        if pln.dateperiod(tz) == Plan::DATE_DESCRIPTION_FUTURE
          #MGS- for future plans, just make the end the same as the start
          event.dtend local_start
        else
          event.dtend local_start + pln.duration
        end
      end

      #MGS- all events must have an organizer, it's not optional
      owner = pln.owner
      organizer = Vpim::Icalendar::Address.create(build_user_uid(owner))
      organizer.cn = owner.real_name.blank? ? owner.login : owner.real_name
      event.organizer organizer

      pln.planners.each do |planner|
        #MGS- the owner of the plan should never be in the attendees list
        next if pln.owner.planner == planner
        u = planner.owner
        attendee = Vpim::Icalendar::Address.create(build_user_uid(u))
        attendee.cn = u.real_name.blank? ? u.login : u.real_name
        #MGS- everyone is a required participant, we don't allow for optional attendees
        attendee.role = "REQ-PARTICIPANT"
        #MGS- look up the PARTSTAT value from the PARTSTAT/PLAN_STATUS map
        attendee.partstat = PLAN_STATUS_TO_PARTSTAT[planner.cal_pln_status.to_i]
        #MGS- all of our plans require an RSVP, it's not optional...
        attendee.rsvp = true

        #MGS- add this attendee to the event
        event.add_attendee attendee
      end
      #MGS- set the status for the current user at the top level as well
      event.status(get_plan_status(pln))

      #MGS- add the todo/event to the calendar
      cal.push(event)
    end

    @headers["Content-Type"] = 'text/calendar'
    @headers["Content-Disposition"] = 'filename=your_plans.ics'
    icsfile = cal.encode
    #MGS- debug
    #render :text => icsfile.gsub("\n","<br/>")
    render :text => icsfile
  end


  private

  def build_user_uid(u)
    #MGS- helper to build the unique identifier for users
    return "mailto:" << u.email
  end

  def get_plan_status(pln)
    #MGS- this is a little different than the PARTSTAT's
    if pln.cancelled?
      return 'CANCELLED'
    elsif pln.fuzzy?(current_timezone)
      return 'TENTATIVE'
    else
      return 'CONFIRMED'
    end
  end

  def get_sequence(pln)
    #MGS- set the sequence;  when the plan time is changed we need to increment this count
    # to determine this, we find the number of time changes that have been made to this plan
    # the default value should be zero
    pln.plan_changes.select{ |pc| PlanChange::CHANGE_TYPE_TIME == pc.change_type}.length
  end
end
