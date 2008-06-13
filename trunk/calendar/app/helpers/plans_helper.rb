module PlansHelper

  def build_date_descriptions_collection(timezone)
    #MGS- generate the select for when field
    now = timezone.now
    today = Date.civil(now.year, now.mon, now.day)
    #MGS- since we are displaying Today and Tomorrow as fuzzys,
    # only start displaying days of the week two days from today
    start_day = today + 2
    end_day = today + 7

    dates = [
      [Plan::DATE_DESCRIPTION_FUTURE, 'Some Day in the Future'],
      [Plan::DATE_DESCRIPTION_TODAY, 'Today'],
      [Plan::DATE_DESCRIPTION_TOMORROW, 'Tomorrow'],
    ]

    #MGS- insert the days of the week
    start_day.step(end_day, 1) do |date|
      dates.push(["#{date.mon}/#{date.day}/#{date.year}", "#{date.strftime("%A")} (#{date.mon}/#{date.day})"])
    end

    #MGS- add the extra fuzzys
    dates.concat([
      [Plan::DATE_DESCRIPTION_THIS_WEEKEND, 'Some Day This Weekend'],
      [Plan::DATE_DESCRIPTION_NEXT_WEEKEND, 'Some Day Next Weekend'],
      [Plan::DATE_DESCRIPTION_THIS_WEEK, 'Some Day This Week'],
      [Plan::DATE_DESCRIPTION_NEXT_WEEK, 'Some Day Next Week'],
      [Plan::DATE_DESCRIPTION_CUSTOM, 'Specific Date']
    ])
  end

  def build_time_descriptions_collection(timezone)
    #MGS- generate the select for when field

    return times = [
      [Plan::TIME_DESCRIPTION_ALL_DAY, 'All Day'],
      [Plan::TIME_DESCRIPTION_BREAKFAST, 'Breakfast'],
      [Plan::TIME_DESCRIPTION_LUNCH, 'Lunch'],
      [Plan::TIME_DESCRIPTION_DINNER, 'Dinner'],
      [Plan::TIME_DESCRIPTION_MORNING, 'Morning'],
      [Plan::TIME_DESCRIPTION_AFTERNOON, 'Afternoon'],
      [Plan::TIME_DESCRIPTION_EVENING, 'Evening'],
      [Plan::TIME_DESCRIPTION_CUSTOM, 'Specific Time']
    ]

  end

  def get_planned_days_ago(plan)
    if Plan::DATE_DESCRIPTION_FUTURE == plan.dateperiod(current_timezone)
      today = current_timezone.now.to_date
      date_created = plan.created_at.to_date
      diff = (today - date_created)
      if diff >= 0
        return "<span class=\"invitee\">- planned #{diff} #{diff == 1 ? "day" : "days"} ago</span>"
      end
    end
    return ""
  end

  def get_invitee_lists(plan, user)
    #MGS- takes the array of planners and loops through them checking for acceptance status
    #builds three strings of links for each of the statuses
    accepted, interested, rejected, invited, cancelled = [], [], [], [], []
    #MGS- this can be done with less code like this: planners.sort_by{|cal| cal.owner == current_user ? 0 : 1}
    # but I've read the sort is better than the sort_by for smaller datasets as it does a Schwartzian Transform
    planners = plan.planners.sort{|a,b| (a.owner == current_user ? 0:1) <=> (b.owner == current_user ? 0:1)}

    planners.each do | cal |
      link = link_to(h(cal.owner.display_name), { :controller => 'user', :action => cal.owner.login },
                                                { :onclick => "if (!addToRemoveField('#{h(cal.owner.login)}')){ return false;}"})
      case cal.cal_pln_status.to_i
        when Plan::STATUS_ACCEPTED
          accepted << link
        when Plan::STATUS_INTERESTED
          interested << link
        when Plan::STATUS_INVITED
          invited << link
        when Plan::STATUS_CANCELLED
          cancelled << link
        when *Plan::STATUSES_REJECTED
          rejected << link
        end
      end

    return accepted.join(", "), interested.join(", "), rejected.join(", "), invited.join(", "), cancelled.join(", ")
  end

  #MGS- define the sort order hash
  PLAN_DISPLAY_SORT_ORDER = {
     Plan::STATUS_ACCEPTED => 1,
     Plan::STATUS_INTERESTED => 2,
     Plan::STATUS_INVITED => 3,
     Plan::STATUS_REJECTED => 4,
     Plan::STATUS_CANCELLED => 5
  }.freeze

  def get_sorted_planners(pln)
    #MGS- returns planners sorted by invite status
    planners = pln.planners

    #MGS- deterministically sort the planners by the ordered hash
    planners.sort! do | a, b |
        s = (PLAN_DISPLAY_SORT_ORDER[a.cal_pln_status.to_i] <=> PLAN_DISPLAY_SORT_ORDER[b.cal_pln_status.to_i])
        (s == 0) ? (a.id <=> b.id) : s
    end
    return planners
  end

  def get_plan_header(pln)
    #MGS- returns the header string at the top of the plan details page

    if pln.cancelled?
      return '<div class="picture"><img alt="new plans" src="/images/plan_cancelled.gif" /></div><h2>This plan has been canceled</h2>'
    end

    if logged_in? && !current_user.nil?
      planner = current_user.planner
      if pln.planners.include?(planner)
        #MGS- check for a new plan
        status = pln.planners.find(planner.id).cal_pln_status.to_i
        if Plan::STATUS_INVITED == status
          return '<div class="picture"><img alt="new plans" src="/images/fresh_large.gif" /></div><h2>You\'re Invited!</h2>'
        end
      end
    end
    
    #MES- Not logged in, or conditionally logged in, show them a link that lets them learn more
    return '<div class="picture"><img alt="fuzzy plans" src="/images/fresh_large.gif" /></div><h2><a href="/splash/index">New to Skobee?  Click to learn more.</a></h2>'
  end

  #MES- Returns the name of the class for a sidebar item.  Also returns
  #  the next sidebar number.  The number is zero based.
  def get_sidebar_class(sidebar_number)
    sidebar_number = 0 if sidebar_number.nil?
    #MES- Skobee has one class style for the FIRST sidebar item,
    #  and subsequent sidebar items have a different style.
    if 0 == sidebar_number
      return "section blue", sidebar_number + 1
    else
      return "section grey_middle", sidebar_number + 1
    end
  end

  def sidebar_hover_str(sidebar_number)
    if (sidebar_number.nil? || 0 == sidebar_number)
      return 'onmouseover="dlHoverBlue(this, event)" onmouseout="dlHoverBlue(this, event)"'
    else
      return 'onmouseover="dlHover(this, event)" onmouseout="dlHover(this, event)"'
    end
  end

end


