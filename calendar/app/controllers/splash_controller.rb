class SplashController < ApplicationController
  layout :determine_layout
  before_filter :redirect_if_logged_in, :set_static_includes

  #MGS- the tour pages (except for the email tour pages) shouldn't be visible
  # if you are logged in
  def redirect_if_logged_in
    if logged_in? && ['tour',
                      'tour_dashboard',
                      'tour_planner',
                      'tour_plans',
                      'index'].member?(self.action_name)
      redirect_to :controller => 'planners', :action => 'dashboard'
      return
    end
  end

  #MGS- if we are logged in, then display the application layout as we can see
  # the email tour pages when we are logged in.   the application layout adds the com
  # style to the wrapper div to make sure things still look cool
  def determine_layout
    return logged_in? ? "application" : "splash"
  end

  ###############################################################
  ########  Set the static includes
  ###############################################################
  #MGS- sets the instance variable for js to include
  def set_static_includes
    @javascripts = [JS_SKOBEE_SPLASH, JS_SCRIPTACULOUS_SKOBEE_DEFAULT]
  end
end
