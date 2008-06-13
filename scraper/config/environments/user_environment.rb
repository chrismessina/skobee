module UserSystem
  CONFIG = {
    # Source address for user emails
    :email_from => 'smedberg@gmail.com',

    # Destination email for system errors
    :admin_email => 'smedberg@gmail.com',

    # Sent in emails to users
    :app_url => 'http://localhost:3000/',

    # Sent in emails to users
    :app_name => 'Skobee',

    # Email charset
    :mail_charset => 'utf-8',

    # Security token lifetime in hours
    :security_token_life_hours => 24,

    # Two column form input
    :two_column_input => true,

    # Add all changeable user fields to this array.
    # They will then be able to be edited from the edit action. You
    # should NOT include the email field in this array.
    #KS- i'm adding email to the changeable list despite the above comment. i
    #discussed this with smedberg and neither of us could figure out why they
    #made this comment. smedberg suggested perhaps it was because the email is
    #used in the password salting process, but this doesn't seem to be the case
    #(i changed my email via sql and was still able to log in just fine).
    :changeable_fields => [ 'first_name', 'last_name', 'email', 'home_address',
      'work_address', 'birthday', 'aol_im', 'yahoo_im', 'msn_im', 'icq_im',
      'gtalk_im', 'description' ],
      
    :profile_changeable_fields => [ 'first_name', 'last_name', 'home_address',
      'work_address', 'birthday', 'aol_im', 'yahoo_im', 'msn_im', 'icq_im',
      'gtalk_im', 'description' ],

    # Set to true to allow delayed deletes (i.e., delete of record
    # doesn't happen immediately after user selects delete account,
    # but rather after some expiration of time to allow this action
    # to be reverted).
    :delayed_delete => true,

    # Default is one week
    :delayed_delete_days => 7,

    # Server environment
    :server_env => "#{RAILS_ENV}",
    
    # MES- Should the app contain "remember me" functionality?
    :remember_me => true,
    
    # MES- The number of days to remember me
    :remember_me_days => 14
  }
end
