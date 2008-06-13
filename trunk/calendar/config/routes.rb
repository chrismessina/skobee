ActionController::Routing::Routes.draw do |map|
  # Add your own custom routes here.
  # The priority is based upon order of creation: first created -> highest priority.

  # Here's a sample route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # You can have the root of your site routed by hooking up ''
  # -- just remember to delete public/index.html.
  # map.connect '', :controller => "welcome"

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  map.connect ':controller/service.wsdl', :action => 'wsdl'

  # MGS- Map /splash to the www root : /
  map.connect '/', :controller => 'splash'
  # MGS- any controllers, we dont specify a action for such as help
  # need to be specifically listed here, so they don't get caught
  # by the redirection to the splash controller
  map.connect '/help', :controller => 'help'
  map.connect '/feeds', :controller => 'feeds'
  map.connect '/:action', :controller => 'splash', :action => :action

  #MGS- handle the url from the old signup for Skobee app; this redirects to the splash controller index action
  map.connect '/interested_party/record', :controller => 'splash'

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id'

  #MES- Map any file extension for picture 'show' to the action
  map.connect 'pictures/show/:id', :controller => 'pictures', :action => 'show', :id => /^.*\..*$/
  
  #MES- Make URLs like 'user/marks' map to the planners/show action for that user
  map.connect 'user/:id', :controller => 'planners', :action => 'show', :id => :id

  #MGS- Map the /user to /users to keep from breaking links after the usercontroller name change
  map.connect 'user/:action/:id', :controller => 'users', :action => :action, :id => /\d+/
  
end
