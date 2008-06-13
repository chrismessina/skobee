class UsersController < ApplicationController
  require 'erb'

  model   :user
  include UserHelper
  include ERB::Util


  before_filter :login_required, :set_static_includes, :conditional_login_required
  layout :determine_layout

  Struct.new(
    "MyPlansPrivacy",
    :value
  ).freeze

  PAGES_NOT_REQUIRING_LOGIN = ['login', 'logout', 'edit_password', 'register', 'directions_from_loc', 'forgot_password', 'welcome', 'disable_all_notifications', 'resend_confirm']
  #MGS TODO- while closing the site, don't allow users to signup
  if SHOW_NEW_ACCOUNT_UI
    PAGES_NOT_REQUIRING_LOGIN << 'signup'
  end

  #MGS- only display the full application layout when
  # logged in, either conditionally or not
  def determine_layout
    if logged_in?
      "application"
    else
      "splash"
    end
  end

  def conditional_login_required_for?(action)
    #MGS- allow conditional login for the disable_all_notifications page
    return true if ['disable_all_notifications'].include?(action)
    return false
  end

  def conditional_login_requirement_met?(action_name, current_user_conditions)
    case action_name
        when 'disable_all_notifications'
          #MGS- Check that the disable_all_notifications string matches what's encrypted
          # in the key
          expected_item = UserNotify.conditional_item_for_disable_all_notifications()
          return true if current_user_conditions.include?(expected_item)
    end
    return false
  end

  def login_required_for?(action)
    #MES- Check the constant list of pages that don't require login
    if PAGES_NOT_REQUIRING_LOGIN.include?(action)
      return false
    else
      return true
    end
  end

  def store_loc_before_authenticate?(action_name)
    return false if ['login', 'logout', 'invite_new_user'].include?(action_name)
    return true
  end

  def login
    #MGS- don't let the user get to the login page if they have a session
    # they should have to logoff first
    if logged_in?
      redirect_to :controller => 'planners', :action => 'dashboard'
      return
    end

    #MES- Does the user have a login cookie?
    if cookies[:token] && cookies[:user_id]
      #MES- Attempt to log in using the token
      user = User.authenticate_by_token(cookies[:user_id], cookies[:token])
      if !user.nil?
        set_session_user(user)
        redirect_back
        return
      end
    end
    
    @unregistered_login = nil
    if conditionally_logged_in? && !current_user.registered?
      @unregistered_login = current_user.login
      @unregistered_id = current_user.id
    end

    if !@params['user'].nil? && !@params['user']['login'].nil?
      @login = @params['user']['login']
    elsif conditionally_logged_in? && current_user.registered?
      @login = current_user.login
    else
      @login = ''
    end

    #MES- If the request is a GET, just show the form
    return if show_new_user_on_get

    #MES- If they were conditionally logged in, and now they're logged in, check that
    # it's the same user.  If not, that could be a problem
    if conditionally_logged_in? && @login != current_user.login
      #MES- The login doesn't match, but maybe they logged in by email
      if !current_user.has_email?(@login)
        url = "#{UserSystem::CONFIG[:app_url].to_s}help/your_account#5"
        flash[:error] = "You were just browsing Skobee as #{current_user.login}, but you logged in as #{@login}.  If both accounts are yours, please merge them. <a href='#{url}'>See the merge account help topic for more info.</a>"
      end
    end

    #MES- Perform the login
    user = User.authenticate(@login, @params['user']['password'])
    if !user.nil?
      set_session_user(user)
      #MES- Did the user ask us to remember them?
      if '1' == @params['user']['remember_me']
        #MES- Yes.  Give the user cookies to store the user ID and a login token
        token = user.generate_security_token(UserSystem::CONFIG[:remember_me_days] * 24)
        id = user.id
        cookies[:token] = { :value => token, :expires => UserSystem::CONFIG[:remember_me_days].days.from_now }
        cookies[:user_id] = { :value => id.to_s, :expires => UserSystem::CONFIG[:remember_me_days].days.from_now }
      else
        #MES- They don't want to be remembered, make sure everything is cleared out
        cookies.delete :token
        cookies.delete :user_id
      end

      redirect_back_or_default :controller => 'planners', :action => 'dashboard'
    else
      #MES- Is there an unconfirmed user that corresponds to the login?  If so,
      # we should give them the ability to resend the confirmation email.
      possibly_unverified_user = User.find_by_login(@login)

      if !possibly_unverified_user.nil? && 0 == possibly_unverified_user.verified
        url = url_for(:action => 'resend_confirm', :id => possibly_unverified_user.id)
        flash.now[:error] = "Your Skobee account hasn't been confirmed.  To have Skobee resend a confirmation email, click <a href='#{url}'>here</a>."
      else
        flash.now[:error] = 'The login information you have entered is incorrect. Please try again.'
      end
    end
  end

  def resend_confirm
    #MES- Resend the account confirmation email that was sent at
    # signup, then redirect to login
    begin
      @user = User.find(@params[:id])
    rescue ActiveRecord::RecordNotFound
      @user = nil
    end

    if @user.nil?
      flash[:error] = "The user you wish to confirm could not be found.  Please try again."
    elsif 0 != @user.verified
      flash[:error] = "User '#{@user.login}' has already been confirmed.  Please log in."
    else
      url = url_for(:action => 'welcome') + '?' + login_token_querystring(@user)
      UserNotify.deliver_signup(@user, url)
      flash[:notice] = "A confirmation email has been sent to #{@user.email}.  Follow instructions in the email to complete your registration."
    end

    redirect_to :action => 'login'
  end

  def signup
    #MES- If we're not showing the new account UI, don't let them see this page
    if !SHOW_NEW_ACCOUNT_UI
      redirect_back
      return
    end

    #MES- Are we "international", or US?  Default is US.
    @international = ('1' == @params['intl'])
    @redraw = ('1' == @params['redraw'])

    #MES- If we're conditionally logged in, set up some defaults
    @current_login = nil
    default_user = nil
    if conditionally_logged_in?
      default_user = current_user
      @current_login = default_user.login
      #MES- Blank out the login, 'cause it's apparently confusing (bug 928)
      default_user.login = ''
      #MES- Default the 'international' setting from the user
      @international = default_user.international?
    end

    #MES- If the request is a GET, just show the form
    return if show_new_user_on_get(default_user)
    
    @user = User.new
    set_user_data_from_params(@user, @params)

    #MES- Likewise, if we were asked to redraw the form, it's like a GET.
    return if @redraw

    #MES- Are they trying to make a user for an email that already exists in the system?
    preexisting = User.find_by_email(@params['user']['email'])
    if !preexisting.nil?
      if !preexisting.registered?
        #MES- Do NOT validate uniqueness of the login IF it matches the
        # preexisting login, since we're trying to modify an existing user.
        if @user.login == preexisting.login
          @user.suppress_uniqueness_validation = true
        end
        #MES- The user exists but is not registered, they probably mean to register it
        set_user_data_from_params(preexisting, @params)
        if handle_register_confirm(preexisting, @params)
          #MES- The registration was confirmed or otherwise handled, do NOT render this action
          redirect_to :controller => 'planners', :action => 'dashboard'
          return
        end
      else
        #MES- The email address is already in use AND the user is registered, so
        # we definitely can't use this address.
        flash.now[:error] = "Email address #{@user.email} is already in use. Please try again or use 'forgot my password' to recover your account."
      end
    end

    #MES- Try to save the data into the user
    begin
      User.transaction(@user) do
        @user.new_password = true
        send_email = @user.save
        notice = ''
        if send_email
          notice = "Just one more step! Please check the confirmation email sent to #{@user.email} to complete your registration."
        else
          #MES- If the user is re-signing up with the same login and
          # email as a user that exists and is NOT confirmed, then
          # they probably lost the confirmation email.  We'll resend it.
          dup_user = User.find_by_login(@user.login)
          if !dup_user.nil? && 1 == dup_user.emails.length && @user.email == dup_user.email && Email::UNCONFIRMED == dup_user.email_object.confirmed
            #MES- In this case, the user we want to send is the dup_user
            @user = dup_user
            send_email = true
            notice = "The login and email address you chose have previously been entered into Skobee.<BR/>The confirmation email has been re-sent to #{@user.email}. Please follow the instructions in the email."
          end
        end

        if send_email
          url = url_for(:action => 'welcome') + '?' + login_token_querystring(@user)
          UserNotify.deliver_signup(@user, url)
          flash[:notice] = notice
          #MES- NOTE: Do NOT set the user on the session here.  See bug #618.
          redirect_to :action => 'login'
        else
        end
      end
    rescue Exception => exc
      logger.error "An error occurred delivering signup confirmation email to user #{@user.id}: #{exc}"
      flash.now[:error] = "Skobee was unable to send a confirmation email to #{@user.email}.  Please try again in a few seconds."
    end
  end

  def set_user_data_from_params(user, params)
    user.attributes = params['user']
    #MES- Handle the password separate- the User object doesn't let us set
    # passwords through the hash based "bulk" methods, since this is a possible security
    # hole.
    if !params['pass'].nil?
      user.change_password(params['pass']['password'], params['pass']['password_confirmation'])
    end
  end

  #MES- Register is used by an unregistered user to set up their
  #  Skobee account.  This is used by users who have an account
  #  (e.g. an account made due to an email invite), but who have
  #  never logged in to Skobee.
  def register
    #MES- There are four different paths by which a user may get to this function.
    # First, they might follow an URL that invites them to register with Skobee
    # (e.g. an URL in a reminder email.)  In this case, it's a GET and they're not
    # passing any secret keys or anything like that- they just want to edit their data.
    # Second, they may have entered data into the form (after going through they
    # first path), and they might be posting the data here.  In this case, we want
    # to confirm their identity by sending them a confirmation email.  The URL
    # in the confirmation email should contain enough information for us to
    # complete the registration of their account based solely on the URL (i.e. they
    # shouldn't have to enter more data.)  A special case is when they posted
    # data that was unusable in some way.  In this special case, we reshow the same
    # form, and let them correct the data.
    # Third, they might be following the URL that was sent to them in a confirmation
    # email.  In this case, all the registration data (including a key that authenticates
    # them) should be in the URL.  We should complete the registration for them based
    # on the data in the URL.  As in the second case, they might have some invalid data,
    # so we may have to show the form multiple times to allow them to make changes.
    # A sort of fourth case is a combination of two and three.  If a user comes in with
    # a confirmation URL, but there is a problem, we'll show them the form (pre filled in)
    # so that they can correct problems.  But when they create 'correct' data, we should NOT
    # send them a second confirmation URL!  That'd be super-irritating.  Instead,
    # we should recognize that though they're posting corrected data, they've already been
    # confirmed, so we don't need to confirm them again- we can apply the changes
    # immediately.

    #MES- Get the user
    @user = User.find(@params['id'])
    #MES- Is the user already registered?
    if @user.registered?
      #MES- They're registered, send them to login
      flash[:notice] = "You are already registered.  Please log in."
      redirect_to :action => 'login'
      return
    end

    #MES- Are we "international", or US?  Default is US.
    @international = ('1' == @params['intl'])
    @current_login = nil

    #MES- Did they get here from a registration confirmation email?  If so,
    # they've passed in all the info needed to complete registration,
    # so do it now.
    if @params.has_key?('p') && @params.has_key?('key')
      #MES- Check that the key is good, and that the salted password is the right length
      u_auth = User.authenticate_by_token(@params['id'], @params['key'])
      if (User::HASH_LENGTH != @params['p'].length) || u_auth.nil?
        #MES- Bad or out of date key!
        flash.now[:error] = 'The URL is not valid.  Verify your URL.'
      else
        #MES- We've authenticated using the key in the URL, we're effectively logged
        # in, make it official.
        @user = u_auth
        set_session_user(@user)
        #MES- Make a hash that has only the user info, and put it into the user
        @user.attributes = @params['user']
        #MES- Check that everything is still valid.  If not, fall through to display
        # stuff normally- the errors on the user object will be displayed in the
        # flash area.
        if @user.valid?
          #MES- The user info is valid, put the salted password and store the user
          @user.salted_password = @params['p']

          #KS- set the user's notification settings to the new user defaults
          @user.set_notifications_to_default()

          @user.save

          flash[:notice] = "Thanks for joining Skobee! Your account has been activated and you are good to go."
          redirect_to :controller => 'planners', :action => 'dashboard'
          return
        end
      end
    end

    #MES- Was this a get?  If so, show the page
    if :get == @request.method
      #MES- In this case, we don't want to show the existing login, because
      # it confuses users.  See bug 928
      @current_login = @user.login
      @user.login = ''
      render
      return
    end

    #MES- They posted data, try to handle it by sending a confirmation or similar.
    set_user_data_from_params(@user, @params)
    if handle_register_confirm(@user, @params)
      #MES- The registration was confirmed or otherwise handled, do NOT render this action
      redirect_back_or_default :controller => 'users', :action => 'login'
      return
    end
  end

  def handle_register_confirm(user, params)
    #MES- Validate the data. If the user's valid, send a confirm email.
    # If not, return false so that the caller can re-render the page,
    # allowing the user to correct the data.

    if user.valid?
      if logged_in? && current_user_id == user.id
        #MES- Since they're logged in as this user, just save the data.
        # We don't need to send a confirmation email, since they've effectively
        # confirmed (to get logged in, they must have gone through a confirmation
        # email- don't make them do it again.)
        user.save
        flash[:notice] = "Thanks for joining Skobee! Your account has been activated and you are good to go."
      else
        #MES- Send them a confirmation email
        # We want to include all the info they sent us in the URL.  That way, we don't have to
        # hold some junk on our end.  But we don't want to send the password in cleartext, since
        # anyone reading the email can then see the password.  We will send the encrypted
        # password (i.e. the one we store in the DB.)  This shouldn't be dangerous, since they
        # don't have the salt and they can't log in with the encrypted password (they need the
        # UNENCRYPTED password to log in.)

        #MES- Throw away all the user settings- we don't want to save them!  Since the
        # generation of the security token does a save, it's important to throw the data away.
        user = User.find(user.id)
        salted_pass = User.generate_salted_password(user.update_salt, params['pass']['password'])
        security_key = user.generate_security_token

        #MES- Convert the user @params into the correct items
        # for an URL.
        url_opts = {}
        params['user'].each_pair do | key, value |
          url_opts["user[#{key}]"] = value
        end

        #MES- Add the standard arguments
        url_opts.merge!({ :controller => 'users', :action => 'register', :id => user.id, :p => salted_pass, :key => security_key })
        url = url_for(url_opts)

        begin
          UserNotify.deliver_confirm_register(user, url)
          flash[:notice] = "Just one more step! Please check the confirmation email sent to #{@user.email} to complete your registration."
        rescue Exception => exc
          logger.error "An error occurred delivering register confirmation email to user #{user.id}: #{exc}"
          flash.now[:notice] = "Skobee was unable to send a confirmation email to #{user.email}.  Please try again in a few seconds."
          return false
        end
      end
      return true
    else
      return false
    end
  end

  def logout(delete_token = true)
    if delete_token && !current_user.nil?
      #MES- Delete any login token
      current_user.destroy_security_token()
    end

    clear_session_user
    cookies.delete :token
    #MES- We leave the :user_id cookie, so that the login page will know
    # that this user likes to use "remember me"

    #MGS- ensure that it renders the action 'logout'
    # If this isn't explicitly set, the delete action (which
    # calls the logout action)...will try to render the view
    render(:action => 'logout')
  end

  def settings
    store_location
    render(:template => "users/settings")
  end

  def forgot_password

    #MES- If the request is a GET, just show the form
    return if show_new_user_on_get

    # Handle the :post
    if @params['user']['email'].empty?
      flash.now[:error] = 'Please enter a valid email address.'
    elsif (user = User.find_by_email(@params['user']['email'])).nil?
      flash.now[:error] = "We could not find a user with the email address #{@params['user']['email']}."
    else
      begin
        User.transaction(user) do
          url = url_for(:action => 'edit_password')
          url += '?'
          url += login_token_querystring(user)
          UserNotify.deliver_forgot_password(user, url)
          flash[:notice] = "Instructions on resetting your password have been emailed to #{@params['user']['email']}."
          if !logged_in?
            redirect_to :action => 'login'
            return
          end
          redirect_back_or_default  :controller => 'planners', :action => 'dashboard'
        end
      rescue
        flash.now[:error] = "Your password could not be emailed to #{@params['user']['email']}."
      end
    end
  end

  #KS- this is used by unregistered users to turn off all notifications so they don't get bothered
  def disable_all_notifications
    @user = current_user

    return if show_session_user_on_get

    if @params['disable'] == "on"
      @user.set_att(UserAttribute::ATT_REMIND_BY_EMAIL, 0)
    end
  end

  def edit_notifications
    @user = current_user

    #KS- yes, this is a bit odd, but i am (probably temporarily) making the
    #edit notifications form input hours instead of minutes
    reminder_hours = @user.get_att_value(UserAttribute::ATT_REMINDER_HOURS)
    reminder_hours *= 60 if !reminder_hours.nil?

    return if show_session_user_on_get

    set_atts_from_post(@params, @user)

    #MES- Unfortunately, set_atts_from_post can't do the right thing for missing
    # checkboxes, because it doesn't have a way to know they're missing!  Therefore,
    # we need to fix up the ATT_PLAN_COMMENTED_NOTIFICATION_OPTION setting if it's
    # NOT in the post.
    if !@params['user_atts'].has_key?(UserAttribute::ATT_PLAN_COMMENTED_NOTIFICATION_OPTION.to_s)
      @user.set_att(UserAttribute::ATT_PLAN_COMMENTED_NOTIFICATION_OPTION, UserAttribute::FALSE_USER_ATT_VALUE)
    end


    flash[:notice] = 'Your notification settings were updated successfully.'

    redirect_to :controller => 'users', :action => 'settings'
  end

  def edit_profile
    @user = current_user

    #MGS- if we have a special parameter on the querystring, flash a message to the user
    if params[:set_flickr_tag]
      flash[:notice] = "You need to set your Flickr ID to add photos to your plan."
      flash[:redirect_to_plan] = true
    end

    #MES- The flickr ID is handled in a special way, since it has a checkbox
    current_flickr_id = @user.get_att_value(UserAttribute::ATT_FLICKR_ID)
    if current_flickr_id.nil?
      @flickr_desired = false
      @flickr_id = @user.email
    else
      @flickr_desired = true
      @flickr_id = current_flickr_id
    end

    return if show_session_user_on_get

    #KS- remove the gender if it's unknown and do not save it
    if @params['user_atts'][UserAttribute::ATT_GENDER.to_s] == UserAttribute::GENDER_UNKNOWN.to_s
      @params['user_atts'].delete(UserAttribute::ATT_GENDER.to_s)
      @user.delete_att(UserAttribute::ATT_GENDER)
    end

    #KS- remove the relationship status if it's unknown and do not save it
    if @params['user_atts'][UserAttribute::ATT_RELATIONSHIP_STATUS.to_s] == UserAttribute::RELATIONSHIP_TYPE_UNKNOWN.to_s
      @params['user_atts'].delete(UserAttribute::ATT_RELATIONSHIP_STATUS.to_s)
      @user.delete_att(UserAttribute::ATT_RELATIONSHIP_STATUS)
    end

    #KS- delete the birth year from the user and the params hash if it's blank
    if @params['user_atts'][UserAttribute::ATT_BIRTH_YEAR.to_s].blank?()
      @user.delete_att(UserAttribute::ATT_BIRTH_YEAR)
      @params['user_atts'].delete(UserAttribute::ATT_BIRTH_YEAR.to_s)
    end

    #KS- save all of the user attributes
    set_user_data_from_params(@user, @params)
    set_atts_from_post(@params, @user)

    #MES- Handle the Flickr data separately, it has a checkbox
    if !@params['flickr_desired'].nil?
      @user.set_att(UserAttribute::ATT_FLICKR_ID, @params['flickr_id'])
    else
      @user.delete_att(UserAttribute::ATT_FLICKR_ID)
    end

    if @user.save
      flash[:notice] = 'Your profile was updated successfully.'

      #MGS- special case where we want to redirect back to the plan after setting flickr ID
      if flash[:redirect_to_plan]
        redirect_back
      else
        redirect_to :controller => 'planners', :action => 'show'
      end
    end
  end

  def edit_privacy
    @current_user = current_user

    @my_plans_privacy_options = []
    Planner::PLANS_PRIVACY_SETTINGS.each {|key|
      @my_plans_privacy_options << [ key.to_s, SkobeeConstants::PRIVACY_SETTINGS_NAMES[key] ]
    }
    @my_plans_privacy_options[0][1] = "#{@my_plans_privacy_options[0][1]} (default)"
    @my_plans_privacy = Struct::MyPlansPrivacy.new(@current_user.planner.visibility_type)

    privacy_options = []
    SkobeeConstants::PRIVACY_SETTINGS_NAMES.each { |key, value|
      privacy_options << [ key.to_s, value ]
    }

    #KS- set privacy option names for specific fields (so that we can label the
    #defaults in the selection boxes)
    @real_name_privacy_options = []
    UserAttribute::REAL_NAME_PRIVACY_SETTINGS.each do | setting |
      @real_name_privacy_options << [ setting.to_s, SkobeeConstants::PRIVACY_SETTINGS_NAMES[setting] ]
    end

    #MES- TODO: I don't understand why these particular settings are default.  Maybe we should
    # have constants that indicate which one is default?  That is, this code is hard to read
    # because I can't tell what "@real_name_privacy_options[1][1]" means.
    @real_name_privacy_options[1][1] = "#{@real_name_privacy_options[1][1]} (default)"
    @any_friends_default_options = Array.new(privacy_options.length){|i| Array.new(privacy_options[i])}
    @any_friends_default_options[2][1] = "#{@any_friends_default_options[2][1]} (default)"
    @only_me_default_options = Array.new(privacy_options.length){|i| Array.new(privacy_options[i])}
    @only_me_default_options[3][1] = "#{@only_me_default_options[3][1]} (default)"
    @all_skobee_default_options = Array.new(privacy_options.length){|i| Array.new(privacy_options[i])}
    @all_skobee_default_options[1][1] = "#{@all_skobee_default_options[1][1]} (default)"

    return if show_session_user_on_get

    #TODO: ensure all inputs are in legal ranges

    #KS- delete my_plans_privacy from the params array; it is set in the planner
    #not the user
    my_plans_privacy = @params['my_plans_privacy']
    @params.delete('my_plans_privacy')

    #KS- save my plans privacy
    if !my_plans_privacy.nil? && Planner::PLANS_PRIVACY_SETTINGS.include?(my_plans_privacy['value'].to_i)
      @user.planner.visibility_type = my_plans_privacy['value']
      @user.planner.save
    end

    #KS- save the user attributes (everything but my plans privacy)
    set_security_atts_from_post(@params, @current_user)

    flash[:notice] = 'Your privacy settings were updated successfully.'

    redirect_to :controller => 'users', :action => 'settings'
  end

  def edit_email
    return if show_session_user_on_get

    email_string = @params['email_to_operate_on']

    #KS- if the email string is blank, tell them to select an email
    if email_string.blank?
      flash.now[:error] = 'You must select an email address to operate on.'
      return
    end

    user_id = current_user_id
    if !email_string.nil?
      email = Email.find_first ["address = :address AND user_id = :user_id", {:address => email_string, :user_id => user_id}]
    end

    user = current_user
    case @params['action_type']
      when 'resend'
        resend_confirmation_email(email)
      when 'primary'
        make_email_primary(email, user)
      when 'delete'
        delete_email(email, user)
      else
        raise 'Error: unrecognized action type in UsersController#edit_email'
    end
  end

  def resend_confirmation_email(email)
    if email.confirmed == Email::CONFIRMED
      flash.now[:error] = 'Email already confirmed'
    else
      primary_owner = User.find_by_primary_email_address(email.address)

      if primary_owner.nil?
        send_confirmation_email(current_user, email)
      else
        send_merge_email(current_user, email, primary_owner)
      end
      flash.now[:notice] = 'A confirmation email has been sent'
    end
  end

  def make_email_primary(email, user)
    if email.confirmed == Email::CONFIRMED
      user_id = user.id
      begin
        User.transaction(user) do
          old_primary_email = user.emails.select{|loop_email| loop_email.primary == Email::PRIMARY}[0]
          old_primary_email.primary = Email::NOT_PRIMARY
          old_primary_email.save
          new_primary_email = user.emails.select{|loop_email| loop_email.address == email.address}[0]
          new_primary_email.primary = Email::PRIMARY
          new_primary_email.save
        end
      rescue
        flash.now[:error] = 'Error setting email to primary'
      end
    else
      flash.now[:error] = 'Must first confirm an email before setting it to primary'
    end
  end

  def delete_email(email, user)
    user_id = user.id

    if email.nil?
      flash[:notice] = 'You must select an email to delete.'
    elsif email.primary == Email::PRIMARY
      flash[:notice] = 'You can\'t delete your primary email address.'
    else
      Email.delete(email.id)
    end
  end

  def add_email
    new_email_string = @params['new_email']
    user = current_user
    new_email = Email.new
    new_email.user_id = user.id
    new_email.address = new_email_string

    email_array = user.emails.select{|email| email.address == new_email_string}
    if email_array.length == 0
      user.emails << new_email
      errors_found = false
      errors = []
      if !new_email.save
        errors_found = true
        new_email.errors.each{|key, message|
          errors << "Email " + message
        }
        flash[:error] = errors
      end

      if !errors_found
        flash[:notice] = "A confirmation email has been sent to #{new_email.address}"
        primary_owner = User.find_by_email(new_email.address)
        if primary_owner.nil?
          #KS- send a vanilla confirmation email if no one has this listed as their primary email
          send_confirmation_email(user, new_email)
        else
          #KS- send a merge email if we found someone else who has the new email as a primary email
          send_merge_email(user, new_email, primary_owner)
        end
      end
    else
      flash[:error] = 'You can\'t add the same email twice.'
    end

    redirect_to :controller => 'users', :action => 'edit_email'
  end

  def send_merge_email(user, new_email, primary_owner)
    url = url_for(:action => 'merge')
    url += '?'
    url += merge_login_token_querystring(primary_owner, new_email, user.id)

    UserNotify.deliver_merge_confirm(user, primary_owner, new_email.address, url)
  end

  def send_confirmation_email(user, new_email)
    url = url_for(:action => 'confirm_email')
    url += '?'
    url += login_token_querystring(user)
    url += "&email=#{CGI::escape new_email.address}"

    UserNotify.deliver_confirm_email(new_email.address, current_user, url)
  end

  def edit_login
    return if show_session_user_on_get


    set_user_data_from_params(@user, @params)

    if @user.save
      flash[:notice] = "Your login has been successfully updated."
    else
      #MES- The login couldn't be changed- the user object didn't validate.
      render
      return
    end

    redirect_to :controller => 'users', :action => 'settings'
  end

  def edit_password
    #MES- Get info from the URL, if it was passed in.  This is used by
    # the "forgot my password" functionality to allow semi-secure authentication
    # by users who have forgotten their passwords.
    @key = @params['key']
    @user_id = @params['user_id']

    return if show_session_user_on_get

    #MES- Authenticate the request.  If this is "forgot my password", then we get the
    # user info from @user_id and @key.  If not, we use the session user and
    # the user should have typed their current password into a field in the form.
    if !@key.nil?
      #MES- Authenticate with the key
      @user = User.authenticate_by_token(@user_id, @key)
      if @user.nil?
        flash.now[:error] = 'The URL is not valid.  Verify your URL.'
        @key = nil
        @user_id = nil
        render
        return
      end

      #MES- Since they've authenticated using the token, they're effectively logged in
      set_session_user(@user)
    else
      #MES- Authenticate with the password
      if User.authenticate(@user.login, @params['user']['current_password']).nil?
        flash.now[:error] = 'Current password is incorrect'
        render
        return
      end
    end

    User.transaction(@user) do
      #MES- Delete the token cookie, changing the password should effectively remove "remember my password"
      cookies.delete :token
      #MES- We leave the :user_id cookie, so that the login page will know
      # that this user likes to use "remember me"
      @user.change_password(@params['user']['password'], @params['user']['password_confirmation'])

      if @user.save
        flash[:notice] = "Your password has been successfully updated."
      else
        #MES- The password couldn't be changed- the user object didn't validate.
        # The user object already set the flash to report the error to the user, we
        # just need to re-render this page.
        render
        return
      end
    end

    redirect_to :controller => 'users', :action => 'settings'
  end

  def contacts
    #MES- View/edit the contacts list for the current user
    @user = current_user
    @friend_contacts = @user.friend_contacts
    @friends = @user.friends
    @recently_added_me = User.find_recently_added_me_as_friend(@user)

    store_location
  end

  def contacts_inverse
    #MGS- View/edit the inverse contacts list for the current user
    @user = current_user
    @combined_contacts = User.find_contacts_inverse(@user)

    @recently_added_me = User.find_recently_added_me_as_friend(@user)
    @friends = @user.friends

    store_location
  end

  def delete
    @user = current_user
    begin
      if UserSystem::CONFIG[:delayed_delete]
        User.transaction(@user) do
          key = @user.set_delete_after
          url = url_for(:action => 'restore_deleted')
          url += '?'
          url += login_token_querystring(@user, key)
          UserNotify.deliver_pending_delete(@user, url)
        end
      else
        destroy(@user)
      end
      logout false
    rescue
      flash.now[:error] = "The delete instructions could not be sent. Please try again later."
      redirect_back_or_default  :controller => 'planners', :action => 'dashboard'
    end
  end

  def restore_deleted
    login_via_key
    @user = current_user
    @user.deleted = 0
    if not @user.save
      flash.now[:error] = "The account for #{@user['login']} was not restored. Please try the link again."
      redirect_to :action => 'login'
    else
      flash.now[:error] = "The account for #{@user['login']} has been restored."
      redirect_to  :controller => 'planners', :action => 'dashboard'
    end
  end

  def confirm_email
    user = User.find(@params['user_id'])
    user.confirm_email(@params['email'], @params['key'])
    #MGS- TODO looks like there should be a lot more error handling here...

    #MGS- flash a notice and head to the dashboard
    flash[:notice] = "Email address #{@params[:email]} successfully confirmed"
    redirect_to :controller => "planners", :action => "dashboard"
  end

  def merge
    user = User.find(@params['user_id'])
    email_address = @params['email']
    security_token = @params['key']
    if user.nil? || email_address.nil? || security_token.nil?
      flash[:error] = "An error occurred during account merge. Please be sure you copied the URL from your email correctly."
      redirect_to :action => "edit_email"
      return
    end

    #KS- if can't find the merged from user, display an error
    merged_from_user = User.find_by_email(email_address)
    if merged_from_user.nil?
      flash[:error] = "There was an error during the account merge. Please try deleting and adding the email again."
      redirect_to :action => "edit_email"
      return
    end

    #KS- if the user is not logged in as the user with user_id, give an error
    if current_user.id != user.id
      flash[:error] = "You must log in to the account that you are trying to add the email to"
      redirect_to :action => "edit_email"
      return
    end

    #KS- if the email / key combo is not legit, give an error
    if !merged_from_user.email_key_combo_legit?(email_address, security_token)
      flash[:error] = "Invalid email / security token"
      redirect_to :action => "edit_email"
      return
    end

    #KS- if we get all the way past those guard clauses, do the merge and show a confirmation msg
    User.merge(user, merged_from_user)
    #MGS- flash a notice and head to the dashboard
    flash[:notice] = "Email address #{@params[:email]} successfully confirmed"
    redirect_to :controller => "planners", :action => "dashboard"
  end

  def welcome
    #MES- Explicitly login via key.  The user may ALREADY be logged in, but we
    # want to use (and confirm) the user indicated by querystring key.
    if login_via_key
      flash[:notice] = 'Thanks for joining Skobee! Your account has been activated and you are good to go.'
      redirect_to :controller => 'planners', :action => 'dashboard'
      return
    else
      flash[:error] = 'The URL could not be interpreted.  Please double check your URL.'
      redirect_to :action => 'login'
    end
  end

  def invite
    @user = User.find(@params['id'])

    #MES- Was it a form post?
    if :get == @request.method
      render
      return
    end

    #MES- A form post, send an email based on the data
    subject = @params['invite_subject']
    body = @params['invite_body']
    url = url_for(:action => 'register', :id => @user.id)
    UserNotify.deliver_invite(current_user, @user, subject, body, url)

    #MES- Notify the user of what we did
    flash[:notice] = "Invitation sent via email"

    #MES- Return to wherever they came from
    redirect_back
  end

  def invite_new_user
    @invite_to = params[:invite_to]
    @subject = @params['invite_subject']
    @body = @params['invite_body']
    @friend_status = params[:friend_status].to_i
    users_receiving_invitations = []
    #MGS- 2d array of emails and user objects
    existing_users = []
    email_errors = []
    contact_status_updated = false

    if @subject.blank?
      @subject = "#{current_user.full_name} wants you to join Skobee!"
    end

    if @body.blank?
      @body = 'Skobee is a fun way to make plans and invite your friends out to drinks, dinner, or anything you like to do. You can also catch up on what all of your friends are doing and find out where everyone in your city is going.'
    end

    #MGS- Was it a form post?
    if :get == @request.method
      render
      return
    end

    #MGS- adding support for inviting multiple users
    emails = @invite_to.split_delimited_emails()
    #MGS- first loop through the email array and validate that the email is a valid email
    #we don't actually want to create any user accounts unless all the validation passes
    emails.each do |email|
      if !email.is_email?
        #MGS- make sure they've entered a valid email address
        flash.now[:error] = "One or more of the email addresses entered are invalid.  Please check that the emails are properly formatted and separated by commas or semi-colons."
        render
        return
      end
    end
    #MGS- remove duplicate entries if they exist
    emails.uniq!

    if 0 == emails.length
      flash.now[:error] = "You must enter an email address."
      render
      return
    end

    #MGS- now that all the validation has passed, loop through again
    # create the users and send the invites
    emails.each do |email|
      #MGS- first check if this user already exists in skobee
      # if so, don't send a notification and specially alert the inviter in the flash
      existing_user = nil
      existing_user = User.find_by_email(email)
      if !existing_user.nil?
        #MGS- 2d array of emails and user objects
        existing_users << [email, existing_user]
        #MGS- kick out of this iteration
        next
      end

      #MGS- this is indeed a new email address, create a user for it
      @usr = User.create_user_from_email_address(email, current_user)

      #MGS- adding in additional error handling just in case the create_user_from_email_address returns a nil user
      # this will pretty much never happen once we take out the generation limits to invite new users
      if @usr.nil?
        email_errors << email
        #MGS- kick out of this iteration
        next
      else
        users_receiving_invitations << email
      end

      #MGS send an email based on the data
      url = url_for(:action => 'register', :id => @usr)
      #MGS- now send the email
      UserNotify.deliver_invite_new_user(current_user, @usr, @subject, @body, url)

      if [User::FRIEND_STATUS_FRIEND, User::FRIEND_STATUS_CONTACT].member?(@friend_status)
        #MGS- only update the friend status, if setting to friend or contact
        # don't send a email notification of contact change here
        current_user.add_or_update_contact(@usr, { :friend_status => @friend_status})
        contact_status_updated = true
      end
    end

    if !users_receiving_invitations.empty?
      if 1 == users_receiving_invitations.length
        flash[:notice] = "Invitation sent to #{h(users_receiving_invitations[0])}.<br/>"
      else
        flash[:notice] = "Invitations sent to the following emails: #{h(users_receiving_invitations.join(', '))}.<br/>"
      end
    end

    if !existing_users.empty?
      #MGS- handle the case where we have an invitations sent message already in the flash
      if flash[:notice].nil?
        flash[:notice] = ""
      else
        flash[:notice] += "<br/>"
      end

      #MGS- update the contact status of the existing user, only if there previously
      # was no contact status set
      if [User::FRIEND_STATUS_FRIEND, User::FRIEND_STATUS_CONTACT].member?(@friend_status)
        #MGS- only update the friend status, if setting to friend or contact
        # don't send a email notification of contact change here
        existing_users.each do |existing_user|
          #MGS- get the user object out of the array
          usr = existing_user[1]
          #MGS- if the user is trying to set themself as a friend of themself, disallow it
          next if usr == current_user
          if !(current_user.friends + current_user.friend_contacts).include?(usr)
            current_user.add_or_update_contact(usr, { :friend_status => @friend_status})
            contact_status_updated = true
          end
        end
      end

      #MGS- make user messages nice for single/plural notices
      if 1 == existing_users.length
        flash[:notice] += "#{h(existing_users[0][0])} already exists in the system as <a href=\"#{url_for(:controller => 'planners', :action => 'show', :id => existing_users[0][1].id)}\">#{h(existing_users[0][1].login)}</a><br/>"
      else
        flash[:notice] += "These emails already exist in the system:<br/>"
        existing_users.each do |existing_user|
          flash[:notice] += "#{h(existing_user[0])} as user: <a href=\"#{url_for(:controller => 'planners', :action => 'show', :id => existing_user[1].id)}\">#{h(existing_user[1].login)}</a><br/>"
        end
      end
    end

    flash[:notice] += "<br/>Contact status successfully updated." if contact_status_updated

    #MGS- this shouldn't really ever happen, but lets display an error if it does
    if !email_errors.empty?
      flash[:error] = "There was a problem inviting the following users to Skobee: #{h(errors_for_emails.join(','))}."
    end

    redirect_back
  end

  def directions_from_loc
    @place = Place.find(params[:directions_place_id])
    loc = params[:location]

    if params[:is_home]
      #MGS- save this address as the work address
      current_user.set_att UserAttribute::ATT_ZIP, loc
    end
    @url = "http://maps.google.com/maps?q=from%3A+#{CGI::escape loc}+to%3A+#{CGI::escape @place.location}&f=d&hl=en"

    redirect_to @url
  end

  def search
    #MGS- search for contacts
    @recently_added_me = User.find_recently_added_me_as_friend(@user)
    @query = params[:q]
    @friends = current_user.friends
    #MGS- if no search parameters were entered, no sense in executing the query
    return if nil == @query

    store_location

    @results = User.find_by_ft(@query, current_user_id, 100)
  end

  def change_friend_status
    #MGS used from planner show page to change friend status
    contact_id = params[:contact_id].to_i
    status = params[:friend_status].to_i
    new_friend = User.find(contact_id)

    if !current_user.relationship_exists(new_friend.id)
      handle_friend_notification(new_friend, current_user, status)
    end

    current_user.add_or_update_contact(new_friend, { :friend_status => status })
    flash[:notice] = "Contact status successfully updated."

    redirect_back
  end

  def log_break
    #MES- This function puts some text into the log file.  It can be used
    # to tell what is included in a particular page refresh.  You'd go to THIS
    # URL, then the url of interest, then look at the log file.
    # NOTE: There's a possibly easier way to do this on *nix.  Just do something like
    # echo "***********" >> development.log
    logger.info("************************************************")
    logger.info("************************************************")
    logger.info("************************************************")
    render :text => "logged"
  end

  protected

  def destroy(user)
    UserNotify.deliver_delete(user)
    flash[:notice] = "The account for #{user['login']} was successfully deleted."
    user.destroy()
  end

  #MES- If the request was a GET (as opposed to a POST), show the view for
  # the current action, displaying a new User object.
  #NOTE: This code came with SaltedLoginGenerator.
  def show_new_user_on_get(default_user = nil)
    if :get == @request.method
      if default_user.nil?
        @user = User.new()
      else
        @user = default_user
      end
      @user.remember_me = !cookies[:user_id].nil?

      #MGS- check for a specific url on the querystring to redirect to after login
      # currently used by AJAX error handling when the session expires
      if params[:redirect]
        flash[:error] = "Your session has expired.  Please login."
        store_location(params[:redirect])
      end

      render
      return true
    end
    return false
  end

  private

  def handle_friend_notification(new_friend, current_user, status)
    friend_notification = new_friend.get_att_value(UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_OPTION)

    #KS- do we need to send out a notification for this status change?
    if friend_notification == UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_ALWAYS && (status == User::FRIEND_STATUS_FRIEND || status == User::FRIEND_STATUS_CONTACT)
      UserNotify.deliver_friend_notification(new_friend, current_user)
    end
  end

  ###############################################################
  ########  Set the static includes
  ###############################################################
  #MGS- sets the instance variable for js to include
  def set_static_includes
    @javascripts = [JS_SCRIPTACULOUS_SKOBEE_DEFAULT, JS_DATEPICKER, JS_SKOBEE_TIMEZONE]
  end
end
