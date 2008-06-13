module UserSystem

  protected

  SESSION_MEMBER_USER_ID = 'user_id'
  SESSION_MEMBER_CONDITIONS = 'conditions'

  #MES- A few functions to manipulate the current user are below.
  # The basic idea is that we don't want to store the user object
  # in the session.  This would require serializing the user object
  # to the DB, and retrieving it for each page view.  Instead, we
  # store the user ID in the session, and turn it into a user object
  # on demand (and cache it in the request.)
  # This both reduces the amount of data stored in the session, and
  # allows some pages to avoid instantiating the user object at all.
  # Some pages (e.g. AJAX autocomplete pages) might need the user ID, but
  # not the user object.  These pages can grab the ID from the session
  # (using the helper below), and can complete a render without
  # ever instantiating the user object.

  #MES- Get the current user- the user that is logged in.
  # Returns nil if the user is not logged in.
  def current_user
    #MES- If the user is cached, return it
    if !@request.user_obj.nil?
      return @request.user_obj
    end

    #MES- User not cached, is there an ID?
    return nil if current_user_id.nil?

    #MES- Find, cache and return the user
    usr = User.find(current_user_id.to_i)
    @request.user_obj = usr
    return usr
  end

  #MES- Get the ID of the current user, or nil if the user
  # is not logged in.
  def current_user_id
    @session[SESSION_MEMBER_USER_ID]
  end

  def current_timezone
  	usr = current_user
    return usr.tz if !usr.nil?
    return nil
  end

  def current_user_conditions
    @session[SESSION_MEMBER_CONDITIONS]
  end

  #MES- Is the user logged in?
  def logged_in?
    #MES- If they have a userid session variable and they do
    # NOT have conditions, then they're considered logged in.  If they
    # have conditions, then they're not really fully logged in.
    if !@session[SESSION_MEMBER_USER_ID].nil? && @session[SESSION_MEMBER_CONDITIONS].nil?
      return true
    end

    return false
  end

  #MES- Is the user logged in with conditions?
  # NOTE: This function returns FALSE if logged_in? returns TRUE!!
  def conditionally_logged_in?
    #MES If they have a userid session variable and conditions, then
    # they're conditionally logged in.
    if !@session[SESSION_MEMBER_USER_ID].nil? && !@session[SESSION_MEMBER_CONDITIONS].nil?
      return true
    end

    return false
  end

  #MES- Is there a user?  This returns true if logged_in? OR
  # conditionally_logged_in? returns true
  def has_current_user?
    return !@session[SESSION_MEMBER_USER_ID].nil?
  end

  #MES- Set the user we're currently logged in as.
  # This should be called from login code.
  def set_session_user(user, conditional_items = nil)
    @session[SESSION_MEMBER_USER_ID] = user.id
    @request.user_obj = user
    if !conditional_items.nil?
      @session[SESSION_MEMBER_CONDITIONS] = conditional_items
    else
      @session[SESSION_MEMBER_CONDITIONS] = nil
    end
  end

  #MES- Clear the current user.  This should be called
  # from logout code.
  def clear_session_user
    @session[SESSION_MEMBER_USER_ID] = nil
    @session[SESSION_MEMBER_CONDITIONS] = nil
    @request.user_obj = nil
  end

  #MES- This is a before_filter that checks that the user is
  # logged in, or can be logged in via a querystring token.
  # Add it to a controller like this:
  # before_filter :login_required
  def login_required
    #MES- If login is not required, we're done
    return true if !login_required_for?(action_name)

    #MES- If they are logged in, we're done
    return true if logged_in?

    #MES- If they passed a login token in on the command
    # line, log in using it and we're done
    return true if login_via_key


    #MES- NOTE: We do NOT do a token based login through
    # login_via_key.  If a page requires key based login
    # it should call login_via_key directly, since this is
    # a security risk- login_via_key is powerful in the sense
    # that it imparts a "full" login.

    #MES- If they're conditionally logged in, and they got here, then they're trying
    # to see something that is not allowed under their conditions.  This may be confusing, so
    # we add an explanation to the flash.
    if conditionally_logged_in?
      #MES- Show a flash that tells the user they must be logged in
      # to perform the action they tried to take.  See ticket 571.
      message = "You must log in to use this portion of Skobee.<br/><a href='#{url_for :controller => 'users', :action => 'signup'}'>If you don't have an account, click here to sign up.</a>"
      if flash.now[:error].nil?
        flash.now[:error] = message
      else
        flash.now[:error] += "<br>" + message
      end
    end

    #MES- Store the location, if we're supposed to
    store_location if store_loc_before_authenticate?(action_name)

    # call overwriteable reaction to unauthorized access
    access_denied
    return false
  end

  #MES- Override this to tune what actions require full login
  def login_required_for?(action)
    return true
  end

  #MES- Override this to tune what actions do a store_loc when login
  # is required
  def store_loc_before_authenticate?(action_name)
    return true
  end

  #MES- A before filter, similar to login_required.
  # This version requires a conditional login OR a full login,
  # and checks that specified conditions are met.  If you use this,
  # you MUST override conditional_login_requirement_met? and you
  # generally SHOULD override conditional_login_required_for?
  def conditional_login_required
    #MES- If conditional login is not required, we're done
    return true if !conditional_login_required_for?(action_name)

    #MES- If they're logged in, everything is cool.
    # A full login gives all rights of a conditional login, and more.
    return true if logged_in?

    #MES- Try to do a conditional login via the querystring
    conditional_login_via_key

    #MES- If they're conditionally logged in, ask if they
    # can see the thing they want to see
    if conditionally_logged_in?
      return true if conditional_login_requirement_met?(action_name, current_user_conditions)
    end

    #MES- Store the location, if we're supposed to
    store_location if store_loc_before_authenticate?(action_name)

    # call overwriteable reaction to unauthorized access
    access_denied
    return false
  end

  #MES- Override this to tune what actions require conditional login
  def conditional_login_required_for?(action)
    return true
  end

  def basic_authentication_required
    #MGS- basic authentication not required, then we're done
    return true if !basic_auth_required_for?(action_name)

    #MGS- if they're logged in, then we don't want to prompt for a
    # separate basic authentication
    return true if logged_in?

    #MGS- try to do a basic authentication via http headers
    return true if login_via_basic_authentication

    return false
  end

  #MGS- Override this to tune what actions require basic authentication
  def basic_authentication_required_for?(action)
    return true
  end

  # overwrite if you want to have special behavior in case the user is not authorized
  # to access the current operation.
  # the default action is to redirect to the login screen
  # example use :
  # a popup window might just close itself for instance
  def access_denied
    redirect_to :controller => "/users", :action => "login"
  end

  #MES- Override this if you use
  # before_filter :conditional_login_required
  # or users will never be able to get to the page.  The override should
  # check if the conditions correspond to what the user wanted to do.
  def conditional_login_requirement_met?(action_name, current_user_conditions)
    return false
  end

  # store current uri in  the session.
  # we can return to this location by calling return_location
  #MGS- adding the ability to store a specific location to redirect back to
  # used on the login page, when redirected there from an ajax action
  def store_location(url = nil)
    if url.nil?
      @session['return-to'] = @request.request_uri
    else
      @session['return-to'] = url
    end
  end

  # move to the last store_location call or to the passed default one
  def redirect_back_or_default(default)
    if @session['return-to'].nil?
      redirect_to default
    else
      redirect_to @session['return-to']
      @session['return-to'] = nil
    end
  end

  #MES- Try to perform a login based on a key passed in
  # via a querystring parameter.
  def login_via_key
    return false if (@params['user_id'].nil? || @params['key'].nil?)
    id = @params['user_id']
    key = @params['key']
    if id and key
      usr = User.authenticate_by_token(id, key)
      if not usr.nil?
        set_session_user(usr)
        return true
      end
    end

    # Everything failed
    return false
  end

  #MES- Create querystring arguments that can be used with login_via_key to
  # log into the app.
  def login_token_querystring(usr, key = nil)
    #MES- Create a key if none was supplied
    key = usr.generate_security_token if key.nil?
    #MES- Return the string
    return "user_id=#{usr.id}&key=#{key}"
  end

  #KS- Create querystring for merge email (don't add a user_id param as
  #it will be different from the one used to generate the security token)
  def merge_login_token_querystring(usr, new_email, merge_to_user_id)
    #KS- create the key and throw the other arguments all in the query string
    return "key=#{usr.generate_security_token}&email=#{CGI::escape new_email.address}&user_id=#{merge_to_user_id}"
  end

  #MES- Try to perform a login that allows conditional access
  # to only certain items via keys supplied in the querystring
  def conditional_login_via_key
    return false if (@params['user_id'].nil? || @params['ckey'].nil? || @params['cn'].nil?)

    #MES- Put the querystring info into a format we can use
    num_items = @params['cn'].to_i
    items = []
    num_items.times do | idx |
      val = @params["ci#{idx}"]
      if val.nil?
        Raise "Error in UserSystem#conditional_login_via_key, there should be #{num_items} items, but index #{idx} not found"
      end
      items << val
    end

    user_id = @params['user_id']
    usr = User.find(user_id)
    if usr.nil?
      Raise "Error in UserSystem#conditional_login_via_key, user #{user_id} could not be found"
    end

    #MES- What should the hash be?
    correct_hash = User.hashed(UserNotify.conditional_login_querystring_helper(user_id, items) + usr.salt)

    #MES- Were we passed that hash?
    return false if correct_hash != @params['ckey']

    #MES- It's all good, store the info and create the session
    set_session_user(usr, items)
    return true
  end

  def login_via_basic_authentication
    #MGS- set the realm for the basic auth; this is the one
    # required parameter on the W3C spec; default to app_url
    realm = UserSystem::CONFIG[:app_url]

    #MGS- get the basic auth data out of the request with this helper
    username, password = get_auth_data
    #MGS- does the username/password authenticate?
    if user = User.authenticate(username, password)
      #MGS- user exists and password is correct; set the user on the session and roll
      set_session_user(user)
      return true
    else
      #MGS- the user does not exist, the password was wrong, or no authentication header was passed
      @response.headers["Status"] = "Unauthorized"
      @response.headers["WWW-Authenticate"] = "Basic realm=\"#{realm}\""
      #MGS- send a 401 'Access Denied' to the user and show a nice error page
      render(:file => "#{RAILS_ROOT}/public/401.html", :status => 401)
      return false
    end
  end

  private

    #MGS- helper to parse basic authentication data from the header
    def get_auth_data
      user, pass = '', ''
      #MGS- extract authorization credentials
      if request.env.has_key? 'X-HTTP_AUTHORIZATION'
        # try to get it where mod_rewrite might have put it
        authdata = @request.env['X-HTTP_AUTHORIZATION'].to_s.split
      elsif request.env.has_key? 'HTTP_AUTHORIZATION'
        # this is the regular location
        authdata = @request.env['HTTP_AUTHORIZATION'].to_s.split
      end

      #MGS- at the moment we only support basic authentication
      if authdata and authdata[0] == 'Basic'
        user, pass = Base64.decode64(authdata[1]).split(':')[0..1]
      end
      return [user, pass]
    end
end
