# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Use a different logger for distributed setups
# config.logger        = SyslogLogger.new


# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"

# Disable delivery errors if you bad email addresses should just be ignored
# config.action_mailer.raise_delivery_errors = false

#KS- creating new accounts is NOT okay for now.
SHOW_NEW_ACCOUNT_UI = true
#MES- And limit the number of 'generations' for invites.
# E.g. if setting is 1, then new user A can invite user B, but
# user B cannot invite new users (since the generation for B is 1.)
# A negative value means 'no limit.'
MAX_USER_GENERATION = -1

#MGS- constant used to handle redirects properly when running in the
# lighttpd/scgi environment and proxying through another port
# (ie balance running port 80 and the rails app running on port
# 3001)
EXTERNAL_APPLICATION_PORT = 80

#MES- Send agent logging to stdout
LOG_AGENT_TO_STDOUT = true