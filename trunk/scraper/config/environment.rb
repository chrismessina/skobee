# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode
# (Use only when you can't set environment variables through your web/app server)
# ENV['RAILS_ENV'] ||= 'production'

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

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
  
  config.action_mailer.server_settings = {
    :address => 'burnaby.textdrive.com',
    :port => 25,
    :domain => 'skobee.com',
    :user_name => 'michaels',
    :password => '23skobee',
    :authentication => :login
  }

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


require 'environments/localization_environment'
require 'localization'
Localization::load_localized_strings
require 'environments/user_environment'
require_gem 'tzinfo', '= 0.1.0'

#MES- We use open-uri to communicate with geocoding services, etc.
require 'open-uri'
#MES- And we use REXML to parse the returned XML  
require 'rexml/document'

#MES- Force the Timezone classes to be loaded.  If we don't
# do this, restoring a session from the DB may fail.  Sessions
# store User objects, which store Timezone objects.  If the
# definition of Timezone isn't loaded at startup, then we'll
# get an error.
DEFAULT_TZ = TZInfo::Timezone.get('America/Tijuana')

#MES- Set the fixtures to be loaded when rescripting the DB
#MES- It seems like this can't easily be shoved into the
# Rails Initializer, because it's custom.  Anyway, I wasn't
# able to figure out how to do it (though I didn't find the
# doc on Rails::Initializer.)
ActiveRecord::Base.configurations[:fixtures_load_order] = [
  :users,
  :planners,
  :plans,
  :places,
  :comments,
  :planners_plans,
  :comments_plans,
  :comments_places,
  :user_contacts,
  :user_autocomplete,
  :user_atts,
  :pictures,
  :sessions,
  :geocode_cache_entries,
  :feedbacks,
  :place_usage_stats,
  :place_popularity_stats,
  :changes]
  
#MES- TODO: This is the key for localhost:3000.  We need a new key for Skobee.com!
GOOGLE_MAPS_KEY = 'ABQIAAAA5J6dljQKyHiGwsZ4_E10tRTJQa0g3IQ9GZqIMmInSLzwtGDKaBTwvZhgsw5JQLobJ8UOqsVCWQLJHA'
YAHOO_APP_ID = 'i9WUefv8JHSEFhwsf'

MAP_STYLE_GOOGLE = 0
MAP_STYLE_YAHOO = 1
MAP_STYLE = MAP_STYLE_GOOGLE

#MES- Settings for the Mailman agent (to read emails from a POP server.)
#MES- TODO: This should probably be more like actionmailer settings
RECEIVE_MAIL_SERVER = 'skobee.com'
RECEIVE_MAIL_USER = 'planner'
RECEIVE_MAIL_ADDRESS = RECEIVE_MAIL_USER + '@' + RECEIVE_MAIL_SERVER
RECEIVE_MAIL_PASSWORD = 'welcome'