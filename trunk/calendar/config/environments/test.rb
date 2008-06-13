# The test environment is used exclusively to run your application's
# test suite.  You never need to work with it otherwise.  Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs.  Don't rely on the data there!
config.cache_classes = true

# Log error messages when you accidentally call methods on nil.
config.whiny_nils    = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false

# Tell ActionMailer not to deliver emails to the real world.
# The :test delivery method accumulates sent emails in the
# ActionMailer::Base.deliveries array.
config.action_mailer.delivery_method = :test

#KS- creating new accounts is fine in testing or development
SHOW_NEW_ACCOUNT_UI = true
#MES- And limit the number of 'generations' for invites.
# E.g. if setting is 1, then new user A can invite user B, but
# user B cannot invite new users (since the generation for B is 1.)
# A negative value means 'no limit.'
MAX_USER_GENERATION = -1

#MES- Don't send agent logging to STDOUT for tests- it's verbose and annoying
LOG_AGENT_TO_STDOUT = false