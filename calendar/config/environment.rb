# Be sure to restart your web server when you modify this file.
# Uncomment below to force Rails into production mode
# (Use only when you can't set environment variables through your web/app server)
# ENV['RAILS_ENV'] ||= 'production'

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

#MGS- default UserSystem settings;  these settings were moved from user_system.rb.
# Machine specific-settings can be overridden in environment_machine.rb
# This needs to be called before environment_machine.rb is included.
module UserSystem
  CONFIG = {
    # Destination email for system errors
    :admin_email => 'postmaster@skobee.com',
    # Sent in emails to users
    :app_name => 'Skobee',
    :app_reminder_name => 'Skobee Reminder',
    :mail_charset => 'utf-8',
    # Security token lifetime in hours
    :security_token_life_hours => 24,
    # Set to true to allow delayed deletes (i.e., delete of record
    # doesn't happen immediately after user selects delete account,
    # but rather after some expiration of time to allow this action
    # to be reverted).
    :delayed_delete => true,
    :delayed_delete_days => 7,
    :server_env => "#{RAILS_ENV}",
    # MES- Should the app contain "remember me" functionality?
    :remember_me => true,
    :remember_me_days => 14
  }
end

#MGS- environment_machine.rb contains machine-level config settings.
# This file needs to be loaded before the Initializer is loaded in order
# to set the config.action_mailer.server_settings
require 'environment_machine'

Rails::Initializer.run do |config|
  # Skip frameworks you're not going to use
  # config.frameworks -= [ :action_web_service, :action_mailer ]

  # Add additional load paths for your own custom dirs
  config.load_paths += %W( #{RAILS_ROOT}/app/controllers/email )

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  config.action_controller.session_store = :active_record_store

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  # config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/cache"

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc

  # Use Active Record's schema dumper instead of SQL when creating the test database
  # (enables use of different database adapters for development and test environments)
  # config.active_record.schema_format = :ruby

  #MGS- set the action mailer config from the constant set in environment_machine.rb
  # This is a little strange, but I don't think there's a way to set Rails::Configuration
  # settings outside of this block and the individual production/development/tests.rb files
  config.action_mailer.server_settings = ACTION_MAILER_CONFIG_SETTINGS

  # See Rails::Configuration for more options

  ActiveRecord::Base.default_timezone = :utc
end

# Add new inflection rules using the following format
# (all these examples are active by default):
# Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end

# Include your application configuration below
require_gem 'tzinfo', '= 0.2.1'

#MES- We use open-uri to communicate with geocoding services, etc.
require 'open-uri'
#MES- And we use REXML to parse the returned XML
require 'rexml/document'
#MES- We use Flickr for photos
require_gem 'flickr'

#MES- Add our requires, from the lib directory
require 'sk_array'
require 'sk_time'
require 'sk_date'
require 'sk_hash'
require 'sk_string'
require 'sk_object'
require 'sk_rmagick_image'
require 'sk_output_compression'
require 'sk_mysql_loader'
require 'sk_constants'
require 'sk_plandisplay'
require 'sk_sanitize'

#MES- Force the Timezone classes to be loaded.  If we don't
# do this, restoring a session from the DB may fail.  Sessions
# store User objects, which store Timezone objects.  If the
# definition of Timezone isn't loaded at startup, then we'll
# get an error.
DUMMY_TZ = TZInfo::Timezone.get('US/Pacific')

#MES- Set the fixtures to be loaded when rescripting the DB
#MES- It seems like this can't easily be shoved into the
# Rails Initializer, because it's custom.  Anyway, I wasn't
# able to figure out how to do it (though I didn't find the
# doc on Rails::Initializer.)
ActiveRecord::Base.configurations[:fixtures_load_order] = [
  :users,
  :emails,
  :planners,
  :plans,
  :places,
  :comments,
  :planners_plans,
  :comments_places,
  :comments_users,
  :user_contacts,
  :user_atts,
  :pictures,
  :pictures_users,
  :sessions,
  :geocode_cache_entries,
  :feedbacks,
  :place_usage_stats,
  :place_popularity_stats,
  :plan_changes,
  :zipcodes,
  :offsets_timezones
  ]

#MGS- hash of google maps keys
GOOGLE_MAP_KEYS = {
  'localhost:3000' => 'ABQIAAAA5J6dljQKyHiGwsZ4_E10tRTJQa0g3IQ9GZqIMmInSLzwtGDKaBTwvZhgsw5JQLobJ8UOqsVCWQLJHA',
  'alpha.skobee.com' => 'ABQIAAAA5J6dljQKyHiGwsZ4_E10tRS1mkM8nTXoSa2jz4gJshEfXuJOzBSCu0Frp16zxj78U96RqOCRd2-0BA',
  'alpha.skobee.com:4001' => 'ABQIAAAA5J6dljQKyHiGwsZ4_E10tRQXHqA3MM1MGntC-QStg7z9R8K5RBRqhYzQqt4fNyRwIqsAho5xjztCuA',
  'mail.skobee.com:4001' => 'ABQIAAAA5J6dljQKyHiGwsZ4_E10tRT8XtQDwVrjRgyK55I0u59Tv13KSBQnbUFiFs5Eidd2lErlf4ZlZ9Cfiw',
  'mail.skobee.com:3001' => 'ABQIAAAA5J6dljQKyHiGwsZ4_E10tRSHhsd8pKr-PizZBUPasnLa8EUFuhTIOU3tVPRGDJJyo96JOK-oZhE0FQ',
  'db.skobee.com:3001' => 'ABQIAAAA5J6dljQKyHiGwsZ4_E10tRTePpyQ4zLwyxZcIQqZczGQwfFpnhTlFeoEV_i_AR61S-NqA6tRLJRPkA',
  'db.skobee.com' => 'ABQIAAAA5J6dljQKyHiGwsZ4_E10tRRcK8wnzIrL5S_1CLLedzDniSgOVBTDax6l7mMS1Pf2U7WwzFATwiX1Cg',
  'www.skobee.com' => 'ABQIAAAA5J6dljQKyHiGwsZ4_E10tRQmaXdBFJrxE9O42SVVF5tMbeCcaBQgvsRSRRPIPXke-C8vTs93TLDyTA',
  'skobee.com' => 'ABQIAAAA5J6dljQKyHiGwsZ4_E10tRSsqrqiDgmeb_42hPAH9rcvsHm_dRR5apJdRQKqZzvQcXwUxN4w2nPU4w'
}

YAHOO_APP_ID = 'just_to_test'

FLICKR_API_KEY = 'ccf2ce2605454e55bf30f49879f9850b'

###############################################################
########  Javascript Filename Contstants
###############################################################
STATIC_VERSION_ID = "v0.24"
#MGS- these constants map to the js file names
JS_PROTOTYPE = "prototype.js?#{STATIC_VERSION_ID}"
JS_DATEPICKER = "datepicker.js?#{STATIC_VERSION_ID}"
JS_SCRIPTACULOUS_ALL_INCLUDES = "scriptaculous.js?#{STATIC_VERSION_ID}"
JS_SCRIPTACULOUS_SKOBEE_DEFAULT = "scriptaculous.js?#{STATIC_VERSION_ID}"
JS_JSON = "json.js?#{STATIC_VERSION_ID}"

JS_SKOBEE_GENERAL = "skobee.js?#{STATIC_VERSION_ID}"
JS_SKOBEE_PLACES = "places.js?#{STATIC_VERSION_ID}"
JS_SKOBEE_PLANS = "plans.js?#{STATIC_VERSION_ID}"
JS_SKOBEE_PLANNERS = "planners.js?#{STATIC_VERSION_ID}"
JS_SKOBEE_USERS = "users.js?#{STATIC_VERSION_ID}"
JS_SKOBEE_COMMENTS = "comments.js?#{STATIC_VERSION_ID}"
JS_SKOBEE_SPLASH = "splash.js?#{STATIC_VERSION_ID}"
JS_SKOBEE_TIMEZONE = "tz.js?#{STATIC_VERSION_ID}"

#MES- Read the hostname from our environment
HOSTNAME = `hostname`