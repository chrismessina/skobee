#MES- From C:\ruby\lib\ruby\gems\1.8\gems\actionpack-1.12.1\lib\action_controller\request.rb
class ActionController::AbstractRequest

  #MGS- fixing problems with redirects that was only happening on
  # lighttpd/scgi environment and proxying through another port
  # (ie balance running port 80 and the rails app running on port
  # 3001)
  # See site http://habtm.com/articles/2006/01/30/override-port-when-rails-is-behind-a-firewall
  def port
    @port_as_int ||= (RAILS_ENV=="production") ? EXTERNAL_APPLICATION_PORT : env['SERVER_PORT'].to_i
  end

  #MES- Add some stuff to the request that we'd like to have around
  attr_accessor :user_obj
end