require 'user_system'

# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  include ApplicationHelper
  helper :user
  model  :user

  #MES- Use GZip compression to reduce the size of pages returned to the user.
  # See the output_compression plugin (which we are using.)
  after_filter :compress_output
  before_filter :check_browser_version, :login_with_cookie

  HTTP_USER_AGENT = "HTTP_USER_AGENT"
  HTTP_REFERER = "HTTP_REFERER"

  def login_with_cookie
    #MGS-  if the user has a login cookie, and is requesting a page that doesn't require login
    # we should still log them in with their cookie.  This can happen if they save their password,
    # close their browser, and go to www.skobee.com in a new browser window (since SplashController::index
    # doesn't call login_required.
    return if logged_in?

    if cookies[:token] && cookies[:user_id]
      #MGS- Attempt to log in using the token
      user = User.authenticate_by_token(cookies[:user_id], cookies[:token])
      if !user.nil?
        set_session_user(user)
        #MGS- no render/redirect is needed here as we just want the execution of the requested
        # action to continue
        return
      end
    end
  end

  def redirect_back
    #MES- Call the helper function supplied by UserSystem, but pass in a default location
    redirect_back_or_default :controller => 'planners', :action => 'schedule_details'
  end

  def local_request?
    #MES- This function checks if a request is "local" (meaning from a
    # Skobee employee.)  It enables debugging, etc.  We should add our
    # IP addresses once they're solidified.
    ['127.0.0.1', '67.102.229.98'].include?(request.remote_ip)
  end

  def check_browser_version
    # MGS- check the user's browser version once per session
    # If it's a browser we currently don't support...flash a message
    # but only flash this message once per session...
    # There is no Session.onstart in rails...so this is the improvisation.
    #
    # This site has a breakdown of all the HTTP_USER_AGENT strings:
    # http://www.zytrax.com/tech/web/browser_ids.htm

    if session[:checked_browser].nil?
      user_agent = request.env[HTTP_USER_AGENT]

      #MGS- currently we are only supporting Firefox 1.x, IE 6.x and all versions of Safari
      # Also handling the nil user_agent case, as the functional tests don't pass in a user_agent header
      # and theoretically some browsers might not too...
      m = nil
      m = user_agent.match(/(Firefox\/1.)|(MSIE 6.)|(Safari)/) unless user_agent.nil?
      if m.nil? || user_agent.nil?
        flash[:error] = "The browser you are using has not been fully tested by Skobee.  You're welcome to check out the site, but you may run into some problems."
      end

      #MGS- set session variables for the browsers we found
      session[:firefox] = (user_agent.nil? || user_agent.match(/Firefox/).nil?) ? false : true
      session[:ie] = (user_agent.nil? || user_agent.match(/MSIE/).nil?) ? false : true
      session[:safari] = (user_agent.nil? || user_agent.match(/Safari/).nil?) ? false : true

      #MGS- if the user agent is nil, store a blank string as the value of the session setting
      # otherwise store the user agent string
      session[:checked_browser] = user_agent.nil? ? "" : user_agent
      return
    end
  end

  def rescue_action_in_public(exception)
    case exception
      when ActiveRecord::RecordNotFound #, ActionController::UnknownAction
        render(:file => "#{RAILS_ROOT}/public/404.html",
                :status => "404 Not found")
      else
        #MES- Try to record the problem, but if we cannot for some reason, just forget about it
        begin
          #MES- Store a feedback message
          feedback = Feedback.new
          feedback.url = request.request_uri
          feedback.user_id = current_user_id
          feedback.feedback_type = Feedback::FEEDBACK_TYPE_BUG
          feedback.body = "ERROR CAUGHT in rescue_action_in_public: #{exception}"
          feedback.stage = Feedback::FEEDBACK_STAGE_NEW
          feedback.save
        rescue
          #MES- Nothing to do here...
        ensure
          render(:file => "#{RAILS_ROOT}/public/500.html",
                  :status => "500 Error")
        end
      end
  end

  #MGS- adding a cancel action that does a redirect_back
  # this is available from all controllers
  def cancel_and_redirect
    redirect_back
  end
end
