class UserNotify < ActionMailer::Base
  #MES- Kinda crappy, but we use format_rich_text (in ApplicationHelper),
  # which depends on auto_link (in TextHelper), which depends on
  # tag_options (in TagHelper.)
  include ApplicationHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::TagHelper

  #MGS- we will postpend this string to the from address when
  # using a user's full_name as the name value for the email From:
  # We are adding this to make sure emails from Skobee stick out,
  # and so people don't think we're impersonating users...too much.
  EMAIL_FROM_SUFFIX = "[Skobee]"

  def signup(user, url)
    setup_email(user)

    # Email header info
    @subject = "New Account Confirmation"

    # Email body substitutions
    @body["url"] = url
    @body["app_name"] = UserSystem::CONFIG[:app_name].to_s
  end

  def forgot_password(user, url=nil)
    setup_email(user)

    # Email header info
    @subject += "Reset Account Password"

    # Email body substitutions
    @body["name"] = "#{user.full_name}"
    @body["login"] = user.login
    @body["url"] = url || UserSystem::CONFIG[:app_url].to_s
    @body["app_name"] = UserSystem::CONFIG[:app_name].to_s
  end

  def friend_notification(user_added_as_friend, user_adding_friend)
    setup_email(user_added_as_friend)

    @subject = 'You\'ve got a new contact'

    @body['user_adding_friend'] = user_adding_friend
    @body['adding_user_planner_show_url'] = "#{UserSystem::CONFIG[:app_url].to_s}planners/show/#{user_adding_friend.planner.id}"
    @body['adding_user_profile_show_url'] = "#{UserSystem::CONFIG[:app_url].to_s}users/show/#{user_adding_friend.id}"
  end

  def confirm_email(new_email, user, url)
    setup_email(user)
    @recipients = "#{new_email}"

    # Email header info
    @subject = "Email Address Confirmation"

    # Email body substitutions
    @body["name"] = "#{user.full_name}"
    @body["login"] = "#{user.login}"
    @body["url"] = url
    @body["app_name"] = UserSystem::CONFIG[:app_name].to_s
  end

  def merge_confirm(user, primary_owner, new_email, confirmation_url)

    setup_email(user)
    @recipients = "#{new_email}"

    # Email header info
    @subject = "Merge Accounts Confirmation"

    # Email body substitutions
    @body["name"] = "#{user.full_name}"
    @body["url"] = confirmation_url
    @body["app_name"] = UserSystem::CONFIG[:app_name].to_s
  end

  def confirm_register(user, url)

    setup_email(user)

    # Email header info
    @subject = "Registration Confirmation"

    # Email body substitutions
    @body["name"] = "#{user.full_name}"
    @body["url"] = url
    @body["app_name"] = UserSystem::CONFIG[:app_name].to_s
  end

  def pending_delete(user, url=nil)
    setup_email(user)

    # Email header info
    @subject += "Delete user notification"

    # Email body substitutions
    @body["name"] = "#{user.full_name}"
    @body["url"] = url || UserSystem::CONFIG[:app_url].to_s
    @body["app_name"] = UserSystem::CONFIG[:app_name].to_s
    @body["days"] = UserSystem::CONFIG[:delayed_delete_days].to_s
  end

  def update_notification(user, changes, plan, modifying_user)
    from = "#{modifying_user.full_name} #{EMAIL_FROM_SUFFIX}"
    setup_email(user, plan, from)

    #KS- header info
    @subject = !plan.name.nil? && !plan.name.empty? ? plan.name : "Skobee - There's been a change of plans!"

    @body['plan'] = plan
    @body['new_place_name'] = nil
    @body['new_place_location'] = ''
    @body['new_gmap_link'] = ''
    if !plan.place.nil? && !plan.place.name.nil? && !plan.place.name.empty?
      @body['new_place_name'] = plan.place.name if !plan.place.nil? && !plan.place.name.nil? && !plan.place.name.empty?
      if !plan.place.location.nil? && !plan.place.location.empty?
        @body['new_place_location'] = ', ' + plan.place.location
        @body['new_gmap_link'] = "http://maps.google.com/maps?q=#{CGI::escape(plan.place.location)}&iwloc=A&hl=en"
      end
    end

    @body['new_time'] = plan.english_for_datetime(user.tz)

    @body['old_place_name'] = nil
    @body['old_place_location'] = ''
    @body['old_time'] = nil
    changes.each do | change |
      #MES- TODO: It looks to me like this logic doesn't work very well if there are
      # multiple changes.  For example, if the changes list contains a PLACE change
      # and a TIME change, the revert link will only revert ONE of them.  That is,
      # there really should be a revert link for EACH change!
      if PlanChange::CHANGE_TYPE_PLACE == change.change_type
        old_place = change.initial_place
        if !old_place.nil? && !old_place.name.nil? && !old_place.name.empty?
          @body['old_place_name'] = old_place.name
          if !old_place.location.nil? && !old_place.location.empty?
            @body['old_place_location'] = ', ' + old_place.location
            @body['old_gmap_link'] = "http://maps.google.com/maps?q=#{CGI::escape(old_place.location)}&iwloc=A&hl=en"
          end
        else
          @body['old_place_name'] = '[no place selected]'
        end
        @body['old_place_change_id'] = change.id
        @body['revert_link'] = "#{UserSystem::CONFIG[:app_url].to_s}plans/revert/#{plan.id}?change_id=#{change.id}"
      elsif PlanChange::CHANGE_TYPE_TIME == change.change_type
        times = change.initial_time
        @body['old_time'] = Plan::english_for_specified_datetime(user.tz, times[PlanChange::TIME_CHANGE_START_INDEX], times[PlanChange::TIME_CHANGE_TIMEPERIOD_INDEX], times[PlanChange::TIME_CHANGE_FUZZY_START_INDEX], times[PlanChange::TIME_CHANGE_DURATION_INDEX])
        @body['old_time_change_id'] = change.id
        @body['revert_link'] = "#{UserSystem::CONFIG[:app_url].to_s}plans/revert/#{plan.id}?change_id=#{change.id}"
      end
      @body['comment'] = change.comment
    end

    #KS- email body substitutions
    @body['user'] = user
    @body['plan'] = plan
    @body['plan_details_link'] = UserNotify.conditional_url_for_plan(user, plan)
    @body['rsvp_im_in_link'] = "#{UserSystem::CONFIG[:app_url].to_s}planners/accept_plan/#{user.planner.id}?pln_id=#{plan.id}"
    @body['rsvp_im_out_link'] = "#{UserSystem::CONFIG[:app_url].to_s}planners/reject_plan/#{user.planner.id}?pln_id=#{plan.id}"
    #MES- All changes passed in should have the same owner (since they were made together), so
    # just use the first one
    @body['change_owner'] = changes[0].owner
  end

  def plan_comment_notification(user, change, plan, modifying_user)
    from = "#{modifying_user.full_name} #{EMAIL_FROM_SUFFIX}"
    setup_email(user, plan, from)

    #KS- header info
    @subject = !plan.name.nil? && !plan.name.empty? ? plan.name : "Skobee - A comment on a plan"

    @body['plan'] = plan

    comment_unencoded = '[comment is empty]'
    comment_unencoded = change.comment if !change.comment.nil? && !change.comment.empty?
    @body['comment_plain'] = format_plain_text(comment_unencoded)
    @body['comment_html_encoded'] = format_rich_text(comment_unencoded)

    #MES- Figure out how to describe the type of the comment
    case change.change_type
      when PlanChange::CHANGE_TYPE_PLACE_COMMENT
        @body['comment_type'] = ' on the place'
      when PlanChange::CHANGE_TYPE_TIME_COMMENT
        @body['comment_type'] = ' on the date/time'
      else
        @body['comment_type'] = ''
    end

    #KS- email body substitutions
    @body['user'] = user
    @body['plan_details_link'] = UserNotify.conditional_url_for_plan(user, plan)
    @body['change_owner'] = change.owner
  end

  def user_comment_notification(user, comment)
    #MGS- notifier for comments added to your profile
    modifying_user = comment.owner
    from = "#{modifying_user.real_name} #{EMAIL_FROM_SUFFIX}"
    setup_email(user, nil, from)

    @subject = "Skobee - A comment on your profile"

    comment_unencoded = comment.body
    @body['comment_plain'] = format_plain_text(comment_unencoded)
    @body['comment_html_encoded'] = format_rich_text(comment_unencoded)

    #MGS- email body substitutions
    @body['user'] = user
    @body['modifying_user'] = modifying_user
    @body['profile_link'] = "#{UserSystem::CONFIG[:app_url].to_s}planners/show/#{user.planner.id} "
  end

  def delete(user, url=nil)
    setup_email(user)

    # Email header info
    @subject += "Delete user notification"

    # Email body substitutions
    @body["name"] = "#{user.full_name}"
    @body["url"] = url || UserSystem::CONFIG[:app_url].to_s
    @body["app_name"] = UserSystem::CONFIG[:app_name].to_s
  end

  def invite_notification(inviter, user, plan)
    from = "#{inviter.full_name} #{EMAIL_FROM_SUFFIX}"
    setup_email(user, plan, from)

    #KS- make subject the name of the plan if it exists
    @subject = !plan.name.nil? && !plan.name.empty? ? plan.name : "Skobee - New Invitation"

    #KS- email body substitutions
    @body['owner'] = plan.owner
    @body['plan'] = plan
    @body['user'] = user
    if !plan.place.nil? && !plan.place.location.nil?
      @body['gmaps_link'] = "http://maps.google.com/maps?q=#{CGI::escape(plan.place.location)}&iwloc=A&hl=en"
    end
    @body['plan_details_link'] = UserNotify.conditional_url_for_plan(user, plan)
    @body['rsvp_im_in_link'] = "#{UserSystem::CONFIG[:app_url].to_s}planners/accept_plan/#{user.planner.id}?pln_id=#{plan.id}"
    @body['rsvp_im_out_link'] = "#{UserSystem::CONFIG[:app_url].to_s}planners/reject_plan/#{user.planner.id}?pln_id=#{plan.id}"
    @body['email_howto_link'] = "#{UserSystem::CONFIG[:app_url].to_s}email_tour"
  end

  def unregistered_invite_notification(inviter, user, plan, register_url)
    from = "#{inviter.full_name} #{EMAIL_FROM_SUFFIX}"
    setup_email(user, plan, from)

    #KS- header info
    @subject = !plan.name.nil? && !plan.name.empty? ? plan.name : "Skobee - New Invitation"

    #KS- email body substitutions
    @body['owner'] = plan.owner
    @body['plan'] = plan
    @body['user'] = user
    if !plan.place.nil? && !plan.place.location.nil?
      @body['gmaps_link'] = "http://maps.google.com/maps?q=#{CGI::escape(plan.place.location)}&iwloc=A&hl=en"
    end
    @body['plan_details_link'] = UserNotify.conditional_url_for_plan(user, plan)
    @body['rsvp_im_in_link'] = "#{UserSystem::CONFIG[:app_url].to_s}planners/accept_plan/#{user.planner.id}?pln_id=#{plan.id}"
    @body['rsvp_im_out_link'] = "#{UserSystem::CONFIG[:app_url].to_s}planners/reject_plan/#{user.planner.id}?pln_id=#{plan.id}"
    @body['register_link'] = register_url
    @body['disable_notifications_link'] = UserNotify.conditional_url_for_disable_all_notifications(user)
    @body['email_howto_link'] = "#{UserSystem::CONFIG[:app_url].to_s}email_tour"
  end

#MGS TODO - this needs to be hooked up; see bug #501
  def unregistered_remind(user, plan)
    #MGS- per spec use a different name for the Reminder from
    setup_email(user, plan, UserSystem::CONFIG[:app_reminder_name])

    #KS- header info
    @subject = !plan.name.nil? && !plan.name.empty? ? plan.name : "You've got plans #{plan.english_for_datetime(user.tz)}"

    #KS- email body substitutions
    @body['owner'] = plan.owner
    @body['plan'] = plan
    @body['user'] = user
    if !plan.place.nil? && !plan.place.location.nil?
      @body['gmaps_link'] = "http://maps.google.com/maps?q=#{CGI::escape(plan.place.location)}&iwloc=A&hl=en"
    end
    @body['plan_details_link'] = UserNotify.conditional_url_for_plan(user, plan)
    @body['rsvp_im_in_link'] = "#{UserSystem::CONFIG[:app_url].to_s}planners/accept_plan/#{user.planner.id}?pln_id=#{plan.id}"
    @body['rsvp_im_out_link'] = "#{UserSystem::CONFIG[:app_url].to_s}planners/reject_plan/#{user.planner.id}?pln_id=#{plan.id}"
    @body['register_link'] = "#{UserSystem::CONFIG[:app_url].to_s}users/signup"
    @body['disable_notifications_link'] = UserNotify.conditional_url_for_disable_all_notifications(user)
    @body['email_howto_link'] = "#{UserSystem::CONFIG[:app_url].to_s}email_tour"
  end

  def remind(user, plan)
    #MGS- per spec use a different name for the Reminder from
    setup_email(user, plan, UserSystem::CONFIG[:app_reminder_name])

    # Email header info
    @subject = !plan.name.nil? && !plan.name.empty? ? plan.name : "You've got plans #{plan.english_for_datetime(user.tz)}"

    @body['owner'] = plan.owner
    @body['plan'] = plan
    @body['user'] = user
    if !plan.place.nil? && !plan.place.location.nil?
      @body['gmaps_link'] = "http://maps.google.com/maps?q=#{CGI::escape(plan.place.location)}&iwloc=A&hl=en"
    end
    @body['plan_details_link'] = UserNotify.conditional_url_for_plan(user, plan)
    @body['rsvp_im_in_link'] = "#{UserSystem::CONFIG[:app_url].to_s}planners/accept_plan/#{user.planner.id}?pln_id=#{plan.id}"
    @body['rsvp_im_out_link'] = "#{UserSystem::CONFIG[:app_url].to_s}planners/reject_plan/#{user.planner.id}?pln_id=#{plan.id}"
  end

  def fuzzy_expiry_reminder(user, plan)
    #MGS- per spec use a different name for the Reminder from
    setup_email(user, plan, UserSystem::CONFIG[:app_reminder_name])

    # Email header info
    @subject = !plan.name.nil? && !plan.name.empty? ? "#{plan.name} is about to expire!" : "Your plan is about to expire!"

    @body['owner'] = plan.owner
    @body['plan'] = plan
    @body['user'] = user
    if !plan.place.nil? && !plan.place.location.nil?
      @body['gmaps_link'] = "http://maps.google.com/maps?q=#{CGI::escape(plan.place.location)}&iwloc=A&hl=en"
    end
    @body['plan_details_link'] = UserNotify.conditional_url_for_plan(user, plan)
  end

  def unregistered_fuzzy_expiry_reminder(user, plan)
    #MGS- per spec use a different name for the Reminder from
    setup_email(user, plan, UserSystem::CONFIG[:app_reminder_name])

    # Email header info
    @subject = !plan.name.nil? && !plan.name.empty? ? "#{plan.name} is about to expire!" : "Your plan is about to expire!"

    @body['owner'] = plan.owner
    @body['plan'] = plan
    @body['user'] = user
    if !plan.place.nil? && !plan.place.location.nil?
      @body['gmaps_link'] = "http://maps.google.com/maps?q=#{CGI::escape(plan.place.location)}&iwloc=A&hl=en"
    end
    @body['plan_details_link'] = UserNotify.conditional_url_for_plan(user, plan)
    @body['register_link'] = "#{UserSystem::CONFIG[:app_url].to_s}users/register/#{user.id}"
    @body['email_howto_link'] = "#{UserSystem::CONFIG[:app_url].to_s}email_tour"
    @body['disable_notifications_link'] = UserNotify.conditional_url_for_disable_all_notifications(user)
  end

  def created_plan(user, plan, place_was_created)
    #KS- make sure the user has a security token
    user.generate_security_token if user.security_token.nil?

    setup_email(user, plan)

    @recipients = "#{user.email}"
    @subject    = "You made a new plan in Skobee"
    @sent_on    = Time.now
    @body['plan'] = plan
    @body['plan_details_link'] = "#{UserSystem::CONFIG[:app_url].to_s}plans/show/#{plan.id}?cal_id=#{user.planner.id}"
    @body['user'] = user
    @body['did_not_create_link'] = "#{UserSystem::CONFIG[:app_url].to_s}plans/did_not_create/#{plan.id}?user_id=#{user.id}&token=#{user.security_token}"

    #MES- If the place was created through this action, suggest some alternative places
    if place_was_created
      @body['alternate_places'] = Place.find_by_ft_search(user, plan.place.name, false, 4)
    end
  end

  #MES- User 'inviter' wants to invite user 'invitee' to join Skobee.
  # Invitee already has an account, but has not set his or her password,
  # and hence cannot log in.
  def invite(inviter, invitee, subject, main_body, register_url)
    setup_email(invitee)

    @from = "\"#{inviter.full_name.escape_double_quotes} #{EMAIL_FROM_SUFFIX}\" <#{UserSystem::CONFIG[:email_from_user] + UserSystem::CONFIG[:email_from_server]}>"
    @subject = subject
    @body['main_body'] = main_body
    @body['register_link'] = register_url
  end

  #MGS- User 'inviter' wants to invite user 'invitee' to join Skobee.
  # Invitee does not have an account.
  def invite_new_user(inviter, invitee, subject, main_body, register_url)
    setup_email(invitee)

    @from = "\"#{inviter.full_name.escape_double_quotes} #{EMAIL_FROM_SUFFIX}\" <#{UserSystem::CONFIG[:email_from_user] + UserSystem::CONFIG[:email_from_server]}>"
    @subject = subject
    @body['main_body'] = main_body
    @body['inviter'] = inviter
    @body['register_link'] = register_url
  end

  #MES- Notify the user that we couldn't figure out which plan she wanted to
  # edit.
  def unknown_plan_for_email(owner, email, plans)
    #MES- The user sent an email to Skobee to edit a plan, but Skobee wasn't
    # able to figure out which plan the user wanted to edit- the likely plans
    # are in plans, and the email that the user sent is in email.
    setup_response(owner, email)
    @body['plans'] = plans
    @body['user'] = owner
  end

  #MES- Notify the user that a Skobee account was created for them, including
  # a link that lets them register the account.
  def notify_of_registration(user, register_url)
    setup_email(user)
    @subject = 'Skobee Account'
    @body['register_link'] = register_url
  end

  def mailman_pingback(user_info, email, num_received, num_successfully_processed)
    setup_response(user_info, email)
    @body['num_received'] = num_received
    @body['num_successfully_processed'] = num_successfully_processed
  end
  
  def cancel_plan(cancelling_user, user, plan)
    setup_email(user)
    @subject = !plan.name.nil? && !plan.name.empty? ? "#{plan.name} is canceled" : "Your plan is canceled"

    @body['user'] = user
    @body['plan'] = plan
    @body['plan_details_link'] = UserNotify.conditional_url_for_plan(user, plan)
    @body['cancelling_user'] = cancelling_user
  end
  
  def uncancel_plan(uncancelling_user, user, plan)
    setup_email(user)
    @subject = !plan.name.nil? && !plan.name.empty? ? "#{plan.name} is reinstated" : "Your plan is reinstated"

    @body['user'] = user
    @body['plan'] = plan
    @body['plan_details_link'] = UserNotify.conditional_url_for_plan(user, plan)
    @body['uncancelling_user'] = uncancelling_user
  end

  def setup_email(user, plan = nil, from_name = nil)
    if user.is_a? Array
      #MES- An array means this is user info as returned by Mailman::owner_from_email_headers
      @recipients = user[0]
    else
      #MES- We'll assume it's a User object
      @recipients = "#{user.email}"
    end

    #MGS- adding the ability to override the default From: name
    if from_name.nil?
      @from = "#{UserSystem::CONFIG[:app_name]} <#{EmailId.email_address_for_plan(plan)}>"
    else
      #MES- Fix up the from name- encode double quotes properly, since we're going to enclose
      # in double qoutes.
      @from = "\"#{from_name.escape_double_quotes}\" <#{EmailId.email_address_for_plan(plan)}>"
    end

    @subject    = "[#{UserSystem::CONFIG[:app_name]}]"
    @sent_on    = Time.now
    @body["footer"] = <<-END_OF_STRING
________________________________________________________________________________
Would you like to change your email notification settings?
#{UserSystem::CONFIG[:app_url].to_s}users/edit_notifications
    END_OF_STRING

    @body['change_notifications'] = "#{UserSystem::CONFIG[:app_url].to_s}users/edit_notifications"
  end

  #MES- Setup member variables (such as @subject) that should be based on a
  # pre-existing email when we're making a response.
  def setup_response(owner, email)
    #MES- Set up the email in general
    setup_email(owner)

    #MES- If the original email had a subject, make this look like a reply
    if !email.subject.nil? && !email.subject.empty?
      @subject = email.subject
      #MES- If the subject doesn't start with 're: ', prepend that
      if @subject.match(/^[Rr][Ee]:/).nil?
        @subject = 'Re: ' + @subject
      end
    end

    #MES- TODO: Should we handle the HTML body as well?  That'd be slick.
    #MES- Put the original body into the new email, prefixed with '> '
    original_body_arr = []
    email.each do | body_line |
      original_body_arr << '> ' + body_line
    end
    @body["original_body"] = original_body_arr.join('')
  end


#########################################################################
#### MES- Helpers for constructing or manipulating info to be put into
####  emails
#########################################################################


  #MES- Return an URL that can be used to view a plan without
  # being logged in.  The plan will be displayed as the indicated
  # user, but the user can't view other items in the site.
  def self.conditional_url_for_plan(usr, plan)
    #MES- Construct a set of info that identifies the plan
    items = [UserNotify.conditional_item_for_plan(plan.id)]
    qs = conditional_login_querystring(usr, items)
    #MGS- adding cal_id to the querystrings
    return "#{UserSystem::CONFIG[:app_url].to_s}plans/show/#{plan.id}?cal_id=#{usr.planner.id}&#{qs}"
  end

  #MES- A little helper that returns the hash item used to represent a plan
  def self.conditional_item_for_plan(plan_id)
    return "plan#{plan_id}"
  end

  #MGS- Return an URL that can be used to view/edit notification
  # settings without being logged in.
  def self.conditional_url_for_disable_all_notifications(usr)
    #MGS- don't need to pass in any items
    items = [UserNotify.conditional_item_for_disable_all_notifications]
    qs = conditional_login_querystring(usr, items)
    return "#{UserSystem::CONFIG[:app_url].to_s}users/disable_all_notifications?#{qs}"
  end

  #MGS- A little helper that returns a string used to represent a the disable_all_notifications action
  def self.conditional_item_for_disable_all_notifications()
    return "disable_all_notifications"
  end


  #MES- Create querystring arguments that can be used with conditional_login_via_key
  # to access particular items but not others.  The list of items describes what the
  # user should be able to access.  It's passed in as an array of strings
  def self.conditional_login_querystring(usr, items)
    if items.is_a? String
      items = [items]
    end

    #MES- Get the bulk of the querystring via a helper
    qs = conditional_login_querystring_helper(usr.id, items)

    #MES- Hash the qs with some info that's private, so we can
    # tell if the qs has been tampered with.
    key = User.hashed(qs + usr.salt)

    #MES- Append the key to the qs
    qs += "&ckey=#{key}"

    #MES- And we're done!
  end

  def self.conditional_login_querystring_helper(user_id, items)
    #MES- Create the querystring to hold the items
    qs = "user_id=#{user_id}"
    items.each_index do | idx |
      qs += "&ci#{idx}=#{CGI::escape(items[idx])}"
    end

    #MES- Record the number of items, for convenience
    qs += "&cn=#{items.length}"

    return qs
  end
end
