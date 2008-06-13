class FeedsController < ApplicationController
  require 'erb'
  include ERB::Util

  #MGS- enforce basic authentication for all actions in the FeedsController for now
  before_filter :basic_authentication_required, :login_required

  RSS_200_CONTENT_TYPE = "application/xml; charset=utf-8"

  def login_required_for?(action)
    #MGS- only the index action in this controller requires the traditional
    # login page, login; all other actions need to prompt for basic authentication
    return true if action == 'index'
    return false
  end

  def basic_auth_required_for?(action)
    #MGS- only the index action in this controller requires the traditional
    # login page, login; all other actions need to prompt for basic authentication
    #MGS- the user feed is a little different; there's no security on it if the planner
    # is fully public, otherwise it needs the same basic auth security as the other feeds.
    # The security for the user feed is handled in the action, not in a before_filter.
    if 'user' == action
      return false
    elsif ['plans', 'regulars'].include?(action)
    	return false
    else
      return !login_required_for?(action)
    end
  end

  def plan_changes
    #MGS- This feed returns the plan changes for the logged in user
    # it only shows changes that are related to plans they are ACCEPTED on
    # and never shows changes that they created.
    #MGS- if there's not an ID on the querystring, show an error
    return if !check_security(params[:id])

    @plan_changes = PlanChange.find_recent(current_user_id, true, 20)
    #MGS- set the instance variable so the view can access the user
    @current_user = current_user
    rss_setup
    #MGS- set the name and description of the overall feed
    @feed_title = "Skobee: #{h(Inflector.possessiveize(current_user.login))} plan changes"
    @feed_description = "A feed of #{h(Inflector.possessiveize(current_user.login))} plan changes"
    @feed_url = url_for(:controller => 'planners', :action => 'dashboard', :only_path => false)
    render(:template => '/feeds/plan_changes', :layout => false)
  end

  def friends_plans
    #MGS- This feed returns the plan changes created by people on the current user's
    # friend list.  It respects the planner security in deciding what changes to display.
    #MGS- if there's not an ID on the querystring, show an error
    return if !check_security(params[:id])
    #MGS- set the instance variable so the view can access the user
    @current_user = current_user

    #MGS- get the changes for the current user's friends
    @plan_changes = PlanChange.find_contact_recent_changes(@current_user, [User::FRIEND_STATUS_FRIEND])

    rss_setup
    @feed_title = "Skobee: #{h(Inflector.possessiveize(current_user.login))} friends plans"
    @feed_description = "A feed of #{h(Inflector.possessiveize(current_user.login))} friends plans"
    @feed_url = url_for(:controller => 'users', :action => 'contacts', :only_path => false)
    render(:template => '/feeds/plan_changes', :layout => false)
  end


  def all_contacts_plans
    #MGS- This feed returns the plan changes created by people on the current user's
    # friend and contacts list.  It respects the planner security in deciding what
    # changes to display.
    #MGS- if there's not an ID on the querystring, show an error
    return if !check_security(params[:id])
    #MGS- set the instance variable so the view can access the user
    @current_user = current_user
    #MGS- get the changes for the current user's friends and contacts
    @plan_changes = PlanChange.find_contact_recent_changes(@current_user, [User::FRIEND_STATUS_FRIEND, User::FRIEND_STATUS_CONTACT])

    rss_setup
    @feed_title = "Skobee: All #{h(Inflector.possessiveize(current_user.login))} contacts plans"
    @feed_description = "A feed of all #{h(Inflector.possessiveize(current_user.login))} contacts plans"
    @feed_url = url_for(:controller => 'users', :action => 'contacts', :only_path => false)
    render(:template => '/feeds/plan_changes', :layout => false)
  end

  def user
    #MGS- This feed returns plan changes created by a given user.
    #MGS- checking the security for this feed is a little different than the other
    # feeds: for public planners, no security is needed...otherwise it falls into the same
    # security as the other feeds with basic auth.  The planner id is passed on the querystring
    # as is the id of the current user to double check access.
    #MGS- if no planner_id or user id is passed on the query string , show an error
    if !params[:planner_id] || !params[:id]
      render_error_feed("Skobee: Error Displaying this user's plans", "The url requested appears incorrect.  Please try adding the feed again.")
      return
    end

    @current_user = nil
    #MGS- get the planner for the id that was passed in
    planner = Planner.find(params[:planner_id].to_i)
    if SkobeeConstants::PRIVACY_LEVEL_PUBLIC == planner.visibility_type
      #MGS- this is a special case that breaks with traditional Skobee security
      # If the planner is a public planner, then anyone can see this feed
      # WITHOUT being logged in.  We use the ID passed in the querystring to open up
      # the corresponding user object for rendering the feed.  We do not actually log the
      # user in.
      @current_user = User.find(params[:id])
    else
      #MGS- the planner is not set to public, force a login
      if !logged_in?
        #MGS- prompt for authentication with basic auth
        # If this fails, return out of here and a 401 response will
        # be rendered by the helper
        return if !login_via_basic_authentication
      end

      #MGS- set the instance variable so the view can access the user
      @current_user = current_user
      #MGS- get the visibility level for the current user
      vis_level = planner.visibility_level(@current_user)
      if ![Planner::USER_VISIBILITY_LEVEL_OWNER, Planner::USER_VISIBILITY_LEVEL_DETAILS].member?(vis_level)
        #MGS- if the viewing user only has availability level access to the planner they're
        # trying to view, then render the error feed with a message
        render_error_feed("Skobee: Unable to display plan details","This user may have recently changed plans security.")
        return
      end
    end
    

    #MGS- get the plans to display from the planner
    @plan_changes = PlanChange.find_recent_for_user(planner.owner, 20, 0)

    rss_setup
    @feed_title = "Skobee: #{h(Inflector.possessiveize(planner.owner.login))} plans"
    @feed_description = "A feed of #{h(Inflector.possessiveize(planner.owner.login))} plans"
    @feed_url = url_for(:controller => 'planners', :action => 'show', :id=> planner.id, :only_path => false)
    render(:template => '/feeds/plan_changes', :layout => false)
  end
  

  def plans
    #MES- This feed returns the plans for the logged in user.
    
  	#MES- Get the planner and user based on the ID that was passed in.  The ID
  	#	may be the ID of a planner, or the login of a user.
  	plnr, usr = check_planner_user_security(params[:id])
  	
  	#MES- If we couldn't find the planner/user, or they didn't pass security, then give up
  	if (plnr.nil? || usr.nil?)
  		render_error_feed
  		return
  	end
    
    @plans = PlanDisplay.collect_plan_infos(usr, plnr, nil, false)

    #MGS- set the instance variable so the view can access the user
    @current_user = usr
    rss_setup
    #MGS- set the name and description of the overall feed
    @feed_title = "Skobee: #{h(Inflector.possessiveize(usr.login))} plans"
    @feed_description = "A feed of #{h(Inflector.possessiveize(usr.login))} plans"
    @feed_url = url_for(:controller => 'planners', :action => 'dashboard', :only_path => false)
    render(:template => '/feeds/plans', :layout => false)
  end
  
  def regulars
    #MES- This feed returns the 'regulars' for the logged in user-
    #	the users that this user regularly hangs out with.
    
  	#MES- Get the planner and user based on the ID that was passed in.  The ID
  	#	may be the ID of a planner, or the login of a user.
  	#NOTE: We don't actually use the planner for rendering, but we use it to check
  	#	the security level- is the planner public?
  	plnr, usr = check_planner_user_security(params[:id])
  	
  	#MES- If we couldn't find the planner/user, or they didn't pass security, then give up
  	if (plnr.nil? || usr.nil?)
  		render_error_feed
  		return
  	end
  	
    
    @regulars = User.find_regulars(usr.id)

    #MGS- set the instance variable so the view can access the user
    @current_user = usr
    rss_setup
    #MGS- set the name and description of the overall feed
    @feed_title = "Skobee: #{h(Inflector.possessiveize(usr.login))} regulars"
    @feed_description = "A feed of #{h(Inflector.possessiveize(usr.login))} regulars"
    @feed_url = url_for(:controller => 'planners', :action => 'dashboard', :only_path => false)
    render(:template => '/feeds/regulars', :layout => false)
  end

  private
  
  def check_planner_user_security(id)
  	plnr, usr = Planner.find_p_and_u_by_id_or_login(id)
  	
  	#MES- If we couldn't find the planner/user, then give up
  	if (plnr.nil? || usr.nil?)
  		return nil, nil
  	end
  	
  	#MES- If the planner's not public, give up- only public planners are visible through
  	#	this feed
  	if (SkobeeConstants::PRIVACY_LEVEL_PUBLIC != plnr.visibility_type)
  		return nil, nil
  	end
  	
  	return plnr, usr
  end

  def rss_setup
    #MGS- common setup function for all rss feeds;
    #MGS TODO- maybe we add the ability to set the name and description in here as well
    #MGS- set the headers for RSS 2.0
    @headers["Content-Type"] = RSS_200_CONTENT_TYPE
  end

  def check_security(id)
    #MGS- check that the url is properly formatted, we need to have a user_id
    # on the querystring to
    if current_user_id == id.to_i
      return true
    else
      render_error_feed
    end
  end

  def render_error_feed(title = "Skobee: Error displaying feed", desc = "Please check that the url to this feed is correct.")
    #MGS- render the error feed, which is just a blank feed with a description
    # and title of the error
    rss_setup
    @feed_title, @feed_description = title, desc
    render(:template => '/feeds/error', :layout => false)
    return false
  end

end
