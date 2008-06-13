# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes     = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils        = true

# Enable the breakpoint server that script/breakpointer connects to
config.breakpoint_server = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false

# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = false

#KS- creating new accounts is fine in testing or development
SHOW_NEW_ACCOUNT_UI = true
#MES- And limit the number of 'generations' for invites.
# E.g. if setting is 1, then new user A can invite user B, but
# user B cannot invite new users (since the generation for B is 1.)
# A negative value means 'no limit.'
MAX_USER_GENERATION = -1

#MES- Send agent logging to stdout
LOG_AGENT_TO_STDOUT = true

#MGS- Need to set the mime-type of xsl files to be text/xml.
# This is the easy way to do it for Webrick;  we can assume that the
# development environment always runs Webrick, so this will work.  Setting
# the mime-type for xsl files also only appears to be necessary for Firefox.
OPTIONS[:mime_types].update( {"xsl" => "text/xml" })  if defined?(OPTIONS)
