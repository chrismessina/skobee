require File.dirname(__FILE__) + '/../test_helper'
require 'users_controller'

# Raise errors beyond the default web-based presentation
class UsersController; def rescue_action(e) raise e end; end

class UsersControllerTest < Test::Unit::TestCase
  #MES- The User Controller tests cannot use transactional
  # fixtures, for reasons that are not clear to me
  self.use_transactional_fixtures = false

  fixtures :users, :user_contacts, :plans, :planners, :planners_plans, :places, :user_atts, :emails, :zipcodes, :offsets_timezones, :geocode_cache_entries

  assert_valid_markup :login, :signup, :forgot_password

  def setup
    @controller = UsersController.new
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
    @request.host = "localhost"

    @emails = ActionMailer::Base.deliveries
    @emails.clear

    ActionMailer::Base.inject_one_error = false
  end

  #KS- this test is meant to detect the bug where confirming an email that is owned by someone
  #else (and unconfirmed) causes it to be confirmed for the wrong account
  def test_add_and_confirm_someone_elses_unconfirmed_email
    #KS- create a new user
    create_confirmed_user('farkeduser', 'blah@skobee.com', 'asdfasdf')
    farkeduser = User.find_by_string('farkeduser')

    #KS- add another email that coincides with existingbob's unconfirmed email
    login('farkeduser', 'asdfasdf')
    post :add_email, 'new_email' => 'unconfirmed@skobee.com'
    post :confirm_email, :user_id => farkeduser.id, :key => farkeduser.security_token, :email => 'unconfirmed@skobee.com'

    #KS- grab farkeduser out of the db, make sure it has its email intact and confirmed
    farkeduser = User.find_by_string('farkeduser')
    assert_equal 2, farkeduser.emails.length
    assert_equal 2, farkeduser.emails.find_all{|email| email.address == 'blah@skobee.com' && email.confirmed == Email::CONFIRMED}.length

    #KS- grab existingbob, make sure his email is intact
    existingbob = User.find(users(:existingbob).id)
    emails_array = []
    existingbob.emails.each{|email|
      emails_array << email;
    }
    assert_equal 1, emails_array.find_all{|email| email.address == 'existingbob@test.com' && email.primary == Email::PRIMARY && email.confirmed == Email::CONFIRMED}.length
    assert_equal 1, emails_array.find_all{|email| email.address == "unconfirmed@skobee.com" && email.confirmed == Email::UNCONFIRMED}.length
    assert_equal 1, emails_array.find_all{|email| email.address == "existingbob2@test.com" && email.confirmed == Email::CONFIRMED}.length
  end

  def test_merge
    #KS- login as bob
    login

    #KS- add existingbob's primary email
    post :add_email, 'new_email' => 'existingbob@test.com'

    #KS- Get the key, etc., out of the confirmation email
    m = @emails.find_all{|email| email.to[0] == 'existingbob@test.com'}[0].plaintext_body.match(/\/users\/merge\?(.*)$/)
    qs_map = m[1].querystring_to_map

    #KS- bob should have 0 plans before the merge and existingbob should have 6
    bob = User.find(1)
    assert_equal 0, bob.planner.plans.length
    existingbob = User.find(2)
    assert_equal 5, existingbob.planner.plans.length

    #KS- existingbob should exist at this point
    assert !User.find_by_string('existingbob').nil?

    #KS- do the actual merge
    get :merge, qs_map

    #KS- existingbob should no longer exist
    assert_nil User.find_by_string('existingbob')

    #KS- bob should have all of existingbob's plans
    bob = User.find(1)
    assert_equal 5, bob.planner.plans.length
  end

  #KS- make sure the merge only happens if the proper security key is given
  def test_merge_only_works_if_key_is_correct
    #KS- login as bob
    login

    #KS- add existingbob's primary email
    post :add_email, 'new_email' => 'existingbob@test.com'

    #KS- Get the key, etc., out of the confirmation email
    m = @emails.find_all{|email| email.to[0] == 'existingbob@test.com'}[0].plaintext_body.match(/\/users\/merge\?(.*)$/)
    qs_map = m[1].querystring_to_map
    assert_not_nil qs_map['key']
    qs_map['key'] = qs_map['key'] + 'blah'

    #KS- bob should have 0 plans before the merge and existingbob should have 6
    bob = User.find(1)
    assert_equal 0, bob.planner.plans.length
    existingbob = User.find(2)
    assert_equal 5, existingbob.planner.plans.length

    #KS- existingbob should exist at this point
    assert !User.find_by_string('existingbob').nil?

    #KS- do the actual merge
    get :merge, qs_map

    #KS- we should get an error in the flash
    assert flash[:error].match(/Invalid email \/ security token/)

    #KS- existingbob still exist
    assert !User.find_by_string('existingbob').nil?
  end

  #KS- merge should break if not logged in as proper user
  def test_merge_breaks_when_not_logged_in_as_merged_to_user
    #KS- login as bob
    login

    #KS- add existingbob's primary email
    post :add_email, 'new_email' => 'existingbob@test.com'

    #KS- Get the key, etc., out of the confirmation email
    m = @emails.find_all{|email| email.to[0] == 'existingbob@test.com'}[0].plaintext_body.match(/\/users\/merge\?(.*)$/)
    qs_map = m[1].querystring_to_map

    #KS- bob should have 0 plans before the merge and existingbob should have 6
    bob = User.find(1)
    assert_equal 0, bob.planner.plans.length
    existingbob = User.find(2)
    assert_equal 5, existingbob.planner.plans.length

    #KS- existingbob should exist at this point
    assert !User.find_by_string('existingbob').nil?

    #KS- log in as existingbob
    logout
    login('existingbob', 'atest')

    #KS- do the actual merge
    get :merge, qs_map

    #KS- we should get an error in the flash
    assert flash[:error].match(/You must log in to the account that you are trying to add the email to/)

    #KS- existingbob should still
    assert !User.find_by_string('existingbob').nil?
  end

  #KS- this should happen if account1 tries to merge an email address from account2,
  #but before account1 can click the merge confirmation link, the email that was
  #selected to be merged in account2 is deleted from account2
  def test_merge_displays_error
    #KS- login as bob
    login

    #KS- add existingbob's primary email
    post :add_email, 'new_email' => 'existingbob@test.com'

    #KS- Get the key, etc., out of the confirmation email
    m = @emails.find_all{|email| email.to[0] == 'existingbob@test.com'}[0].plaintext_body.match(/\/users\/merge\?(.*)$/)
    qs_map = m[1].querystring_to_map

    #KS- bob should have 0 plans before the merge and existingbob should have 6
    bob = User.find(1)
    assert_equal 0, bob.planner.plans.length
    existingbob = User.find(2)
    assert_equal 5, existingbob.planner.plans.length

    #KS- existingbob should exist at this point
    assert !User.find_by_string('existingbob').nil?

    #KS- change existingbob's email to something else
    #first delete existingbob@test.com
    Email.delete(2)

    #KS- take existingbob's other email (existingbob_unconfirmed_email) and set it
    #to primary/confirmed
    existingbob_other_email = Email.find(26)
    existingbob_other_email.confirmed = Email::CONFIRMED
    existingbob_other_email.primary = Email::PRIMARY
    existingbob_other_email.save!

    #KS- do the actual merge
    get :merge, qs_map

    #KS- there should be an error
    assert flash[:error].match(/There was an error during the account merge. Please try deleting and adding the email again./)

    #KS- bob should have 0 plans before the attempted merge and existingbob should have 6
    #(just like before)
    bob = User.find(1)
    assert_equal 0, bob.planner.plans.length
    existingbob = User.find(2)
    assert_equal 5, existingbob.planner.plans.length
  end

  #KS- added this test in response to a bug with the User#email method. (it was
  #saving when it wasn't supposed to, and thereby blowing away the email.)
  def test_show_does_not_blow_away_email
    assert_equal "bob@test.com", User.find(1).email

    #MGS- deleting users/show action and changing test to planners/show which is the combined
    # profile page.  This has the "about me" sidebar on it so I guess this is the same test,
    # but I'm not sure exactly what this test is supposed to be testing.
    get :controller=>"planners", :action=>:show, :id => 1

    assert_equal "bob@test.com", User.find(1).email
  end

  def test_delete_email
    user_id = 1
    email = Email.find(25)
    user = User.find(user_id)
    assert_equal 3, user.emails.length

    #KS- make sure the emails contain the expected emails
    assert_equal 1, user.emails.select{|email| email.address == "blah@skobee.com"}.length
    assert_equal 1, user.emails.select{|email| email.address == "bob@test.com"}.length

    user_id = 1
    @controller.delete_email(email, user)

    user = User.find(user_id)
    assert_equal 2, user.emails.length

    #KS- make sure the appropriate email was deletedbob@test.com
    assert_equal 1, user.emails.select{|email| email.address == "bob@test.com"}.length
  end

  def test_make_primary_email
    user_id = 1
    email = Email.find(25)
    user = User.find(user_id)
    assert_equal 3, user.emails.length

    #KS- log in bob
    login

    #KS- make sure the emails contain the expected emails
    assert_equal 1, user.emails.select{|email| email.address == "blah@skobee.com"}.length
    assert_equal 1, user.emails.select{|email| email.address == "bob@test.com"}.length
    primary_email_array = user.emails.select{|email| email.primary == Email::PRIMARY}
    assert_equal "bob@test.com", primary_email_array[0].address
    assert_equal 1, primary_email_array.length

    post :edit_email, :email_to_operate_on => "bob@test.com", :action_type => 'primary'

    #KS- make sure the primary email is what we expect it to be
    user = User.find(user_id)
    primary_email_array = user.emails.select{|email| email.primary == Email::PRIMARY}
    assert_equal 1, primary_email_array.length
    assert_equal "bob@test.com", primary_email_array[0].address
  end

  def test_add_email
    post :login, "user" => { "login" => "bob", "password" => "atest" }

    user_id = @request.session['user_id']
    user = User.find(user_id)
    assert_equal 3, user.emails.length

    #KS- precondition, make sure no email was sent yet
    assert_equal 0, ActionMailer::Base.deliveries.size

    post :add_email, 'new_email' => 'umduh@skobee.com'

    #KS- make sure a notification email was sent
    assert_equal 1, ActionMailer::Base.deliveries.size

    user = User.find(user_id)
    assert_equal 4, user.emails.length

    #KS- make sure the added email is unconfirmed
    assert_equal 1, user.emails.select{|email| email.primary == Email::NOT_PRIMARY && email.confirmed == Email::UNCONFIRMED && email.address == 'umduh@skobee.com'}.length

    #KS- test resending the confirmation email
    post :edit_email, :email_to_operate_on => 'umduh@skobee.com', :action_type => 'resend'

    #KS- make sure another confirmation email was sent
    assert_equal 2, ActionMailer::Base.deliveries.size

    #KS- make sure the added email is unconfirmed
    assert_equal 1, user.emails.select{|email| email.primary == Email::NOT_PRIMARY && email.confirmed == Email::UNCONFIRMED && email.address == 'umduh@skobee.com'}.length

    #KS- confirm the just-added email
    post :confirm_email, :user_id => user_id, :key => user.security_token, :email => 'umduh@skobee.com'

    user = User.find(user_id)
    assert_equal 1, user.emails.select{|email| email.primary == Email::NOT_PRIMARY && email.confirmed == Email::CONFIRMED && email.address == 'umduh@skobee.com'}.length

    #KS- try adding a bogus email
    post :add_email, 'new_email' => 'srhbsgsgsgg'
    user = User.find(user_id)
    assert_equal 0, user.emails.select{|email| email.address == 'srhbsgsgsgg'}.length
  end

  def test_auth_bob
    @request.session['return-to'] = "/bogus/location"

    post :login, "user" => { "login" => "bob", "password" => "atest" }
    assert_session_has "user_id"

    assert_equal users(:bob).id, @response.session['user_id']

    assert_redirect_url "http://#{@request.host}/bogus/location"
  end

  def test_signup
    do_test_signup(true, false, false)
    do_test_signup(false, true, false)
    do_test_signup(false, false, false)
    do_test_signup(false, false, true)
  end

  def do_test_signup(bad_password, bad_email, bad_zip)
    ActionMailer::Base.deliveries = []

    mock_opens = {
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=94111' => './test/mocks/resources/94111.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=12345' => './test/mocks/resources/12345.xml'
    }
    with_mock_opens(mock_opens) do
      @request.session['return-to'] = "/bogus/location"

      if not bad_password and not bad_email and not bad_zip
        post :signup, "user" => { "login" => "newbob", "email" => "newbob@test.com", "zipcode" => "94111" }, "pass" => { "password" => "newpassword", "password_confirmation" => "newpassword" }, "intl" => "0"
        assert_session_has_no "user_id"
        assert_redirect_url(@controller.url_for(:controller => 'users', :action => "login"))
        assert_equal 1, ActionMailer::Base.deliveries.size
        mail = ActionMailer::Base.deliveries[0]
        assert_equal "newbob@test.com", mail.to_addrs[0].to_s
        body = mail.plaintext_body
        assert_match Regexp.new('Activate'), body
        m = body.match(/key=([A-Za-z0-9]*)/)
        key = m[1]

        user = User.find_by_login("newbob")
        assert_not_nil user
        assert_equal 0, user.verified
        assert_equal 38.6671, user.lat_max
        assert_equal 36.9279, user.lat_min
        assert_equal(-121.399, user.long_max)
        assert_equal(-123.401, user.long_min)
        assert_equal('94111', user.zipcode)
        #MES- The email is NOT confirmed
        assert_nil User.find_by_email("newbob@test.com")

        # First past the expiration.
        Time.set_advance_by_days(1) do
          get :welcome, "user_id" => "#{user.id}", "key" => "#{key}"
        end
        user = User.find_by_login("newbob")
        assert_equal 0, user.verified

        # Then a bogus key.
        get :welcome, "user_id" => "#{user.id}", "key" => "boguskey"
        user = User.find_by_login("newbob")
        assert_equal 0, user.verified

        # Now the real one.
        get :welcome, "user_id" => "#{user.id}", "key" => "#{key}"
        user = User.find_by_login("newbob")
        assert_equal 1, user.verified

        #KS- assert user notification settings are correct
        assert_equal UserAttribute::TRUE_USER_ATT_VALUE, user.get_att_value(UserAttribute::ATT_REMIND_BY_EMAIL)
        assert_equal UserAttribute::INVITE_NOTIFICATION_ALWAYS, user.get_att_value(UserAttribute::ATT_INVITE_NOTIFICATION_OPTION)
        assert_equal UserAttribute::PLAN_MODIFIED_ALWAYS, user.get_att_value(UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION)
        assert_equal UserAttribute::FALSE_USER_ATT_VALUE, user.get_att_value(UserAttribute::ATT_PLAN_COMMENTED_NOTIFICATION_OPTION)
        assert_equal UserAttribute::CONFIRMED_PLAN_REMINDER_ALWAYS, user.get_att_value(UserAttribute::ATT_CONFIRMED_PLAN_REMINDER_OPTION)
        assert_equal 6, user.get_att_value(UserAttribute::ATT_REMINDER_HOURS).to_i
        assert_equal UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_ALWAYS, user.get_att_value(UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_OPTION)
        assert_equal UserAttribute::TRUE_USER_ATT_VALUE, user.get_att_value(UserAttribute::ATT_USER_COMMENTED_NOTIFICATION_OPTION)

        post :login, "user" => { "login" => "newbob", "password" => "newpassword" }
        assert_session_has "user_id"

        get :logout
      elsif bad_password
        post :signup, "user" => { "login" => "newbob", "email" => "newbob@test.com", "zipcode" => "94111" }, "pass" => { "password" => "bad", "password_confirmation" => "bad" }
        assert_session_has_no "user_id"
        assert_invalid_column_on_record "user", "password"
        assert_success
        assert_equal 0, ActionMailer::Base.deliveries.size
      elsif bad_email
        ActionMailer::Base.inject_one_error = true
        post :signup, "user" => { "login" => "newbob", "email" => "newbob@test.com", "zipcode" => "94111" }, "pass" => { "password" => "newpassword", "password_confirmation" => "newpassword" }
        assert_session_has_no "user_id"
        assert_equal 0, ActionMailer::Base.deliveries.size
      elsif bad_zip
        #KS- i know zipcode 12345 is real (Schenectady, NY) but we intentionally don't enter it in the fixtures, so it's 'bad' as far as the tests are concerned
        post :signup, "user" => { "login" => "newbob", "email" => "newbob@test.com", "time_zone" => "garbage", "zipcode" => "12345" }, "pass" => { "password" => "newpassword", "password_confirmation" => "newpassword" }
        assert_tag :tag => 'div', :content => 'Email address newbob@test.com is already in use'
        assert_tag :tag => 'div', :content => 'Zipcode you entered could not be found.'
        assert_tag :tag => 'div', :content => 'Timezone \'garbage\' is not recognized.'
        assert_tag :tag => 'div', :content => 'Login is already in use.'
        assert_session_has_no "user_id"
        assert_equal 0, ActionMailer::Base.deliveries.size

        #KS- make sure blank zip is not cool
        post :signup, "user" => { "login" => "asdfasdf", "email" => "newbob123@test.com", "zipcode" => "" }, "pass" => { "password" => "newpassword", "password_confirmation" => "newpassword" }
        assert_session_has_no "user_id"
        assert_equal 0, ActionMailer::Base.deliveries.size
      else
        # Invalid test case
        assert false
      end
    end
  end

  def test_signup_preexisting_email
    #MES- When signup is attempted with an email that already exists in the system,
    # the signup should convert to a register (if the preexisting user is unregistered)
    # or should fail validation (if the preexisting user is registered.)

    #MES- Create an unregistered user
    usr = User.create_user_from_email_address('newemail@newemail.com', users(:bob))

    #MES- Try to signup as that user with bad data
    post :signup, "user" => { "login" => usr.login, "email" => "newemail@newemail.com", "zipcode" => "abcde" }, "pass" => { "password" => "newpassword", "password_confirmation" => "does not match" }
    #MES- No delivery should have been made, and we should still be on the
    # signup page, since the data was not actionable.
    assert_success
    assert_equal 0, ActionMailer::Base.deliveries.size
    #MES- Since this is effectively a "register", the user should NOT get errors about duplicate email address
    # or duplicate login.
    assert_no_tag :tag => 'div', :content => /Email address newemail@newemail.com is already in use/
    assert_no_tag :tag => 'div', :content => /The username you entered is already in use/

    #MES- Signup with good data
    post :signup, "user" => { "login" => "newbob", "email" => "newemail@newemail.com", "time_zone" => "US/Pacific", 'zipcode' => User::INTL_USER_ZIPCODE_STR }, "pass" => { "password" => "newpassword", "password_confirmation" => "newpassword" }, "intl" => "1"
    #MES- This should NOT log them in
    assert_session_has_no "user_id"
    assert_redirect_url(@controller.url_for(:controller => 'planners', :action => "dashboard"))
    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries[0]
    assert_equal "newemail@newemail.com", mail.to_addrs[0].to_s
    #MES- The email should contain a link to the register page.
    # We won't test registration, since that's covered in test_register.
    body = mail.plaintext_body
    assert_match Regexp.new("users/register/#{usr.id}"), body

    #MES- Finally, if we try to sign up with an email address that is,
    # taken AND confirmed (but all other signup data is good), that
    # should be a validation error.
    @emails.clear
    post :signup, "user" => { "login" => "onemorebob", "email" => "bob@test.com", "zipcode" => "94111" }, "pass" => { "password" => "newpassword", "password_confirmation" => "newpassword" }
    #MES- The below test is probably what we want it to do, but it doesn't do this now
    #    #MES- No delivery should have been made, and we should still be on the
    #    # signup page, since the data was not actionable.
    #    assert_success
    #    assert_equal 0, @emails.length
    #    assert_tag :tag => 'div', :content => "Email address bob@test.com is already in use. Please try again or use 'forgot my password' to recover your account."
    #MES- Now, it just let's you try to make an account (which you won't be able to confirm.)
    # You'll be redirected to the login page, with a flash message.
    assert_redirect

    #MES- When signup is attempted for a user that exists where the email address is NOT
    # confirmed, the user probably lost the confirm email, so we should send it again.
    # See ticket #975.
    post :signup, "user" => { "login" => "lostemail", "email" => "lostemail@test.com", "zipcode" => "94111" }, "pass" => { "password" => "newpassword", "password_confirmation" => "newpassword" }
    @emails.clear
    post :signup, "user" => { "login" => "lostemail", "email" => "lostemail@test.com", "zipcode" => "94101" }, "pass" => { "password" => "secondpass", "password_confirmation" => "secondpass" }
    assert_equal 1, @emails.length
    #MES- If we confirm that user, they should have a zipcode of 94111 (the ORIGINAL post.)
    body = ActionMailer::Base.deliveries[0].plaintext_body
    m = body.match(/user_id=(\d*)&key=(\w*)/)
    user_id = m[1].to_i
    key = m[2]
    get :welcome, :user_id => user_id, :key => key
    usr = User.authenticate("lostemail", "newpassword")
    assert !usr.nil?
    assert_equal "94111", usr.zipcode
  end

  def test_register
    login
    #MES- Create an unregistered user
    usr = User.create_user_from_email_address('newemail@newemail.com', users(:bob))

    #MES- The register page should be visible for the user
    get :register, :id => usr.id
    assert_success
    assert_valid_markup
    #MES- The login field should NOT be filled in (see bug 928)
    assert_tag 'input', :attributes => {:id => 'user_login', :value => '' }

    #MES- We should be able to post changes to the register page
    #MES- If we post bad data, we should see the page again, with warnings
    # in the flash- there should be NO emails delivered.

    #MES- Passwords don't match
    put :register, :id => usr.id, :user => {:real_name => 'test real name', :login => 'test_login_for_newemail', :zipcode => '94101' }, :pass => { :password => 'test_pass', :password_confirmation => 'bad_pass' }
    assert_success
    assert_tag :tag => 'div', :content => 'Password doesn\'t match confirmation'
    assert_equal 0, @emails.length
    assert_valid_markup
    usr = User.find(usr.id)
    assert !usr.registered?

    #MES- Login taken
    put :register, :id => usr.id, :user => {:real_name => 'test real name', :login => 'bob', :zipcode => '94101' }, :pass => { :password => 'test_pass', :password_confirmation => 'test_pass' }
    assert_success
    assert_tag :tag => 'div', :content => 'Login is already in use.'
    usr = User.find(usr.id)
    assert !usr.registered?

    assert_equal 0, @emails.length

    #MES- Post good data, which should generate a confirmation email
    put :register, :id => usr.id, :user => {:real_name => 'test real name', :login => 'test_login_for_newemail', :zipcode => '94101' }, :pass => { :password => 'test_pass', :password_confirmation => 'test_pass' }
    assert_redirect
    assert_equal 1, @emails.length
    usr = User.find(usr.id)
    assert !usr.registered?

    #MES- Get the key, etc., out of the confirmation email
    m = @emails[0].plaintext_body.match(/\/users\/register\/#{usr.id}\?(.*)$/)
    qs_map = m[1].querystring_to_map
    #MES- Add in the user ID
    qs_map[:id] = usr.id

    #MES- We should NOT be able to register with a bad URL

    #MES- What if the key has been cut off or tampered with?
    bad_map = qs_map.clone
    bad_map['key'] = bad_map['key'][1,30]
    get :register, bad_map
    assert_success
    assert_tag :tag => 'div', :attributes => { :id => "flash-error" }, :content => /The URL is not valid\.  Verify your URL\./

    #MES- What if the password has been cut off or tampered with?
    bad_map = qs_map.clone
    bad_map['p'] = bad_map['p'] + '_test'
    get :register, bad_map
    assert_success

    #MES- What if the login is taken?
    bad_map = qs_map.clone
    bad_map['user']['login'] = 'bob'
    get :register, bad_map
    assert_success
    assert_tag :tag => 'div', :content => 'Login is already in use.'

    #MES- Since we passed in a good key before, we should be authenticated.
    # If we now post good data, but NO key, we should NOT get a confirmation
    # email- the changes should take place immediately.
    put :register, :id => usr.id, :user => {:real_name => 'test real name', :login => 'test_login_for_newemail', :zipcode => '94101' }, :pass => { :password => 'test_pass', :password_confirmation => 'test_pass' }
    assert_redirect
    assert_equal 1, @emails.length  #MES- Same length as before
    #MES- We should be able to log in using our new login and password
    new_u = User.authenticate('test_login_for_newemail', 'test_pass')
    assert !new_u.nil?
    #MES- And the data should be set
    assert_equal usr.id, new_u.id
    assert_equal 'test real name', new_u.real_name

    #MES- If we post the same data again, we should be redirected to the login page
    put :register, :id => usr.id, :user => {:real_name => 'test real name', :login => 'test_login_for_newemail', :zipcode => '94101' }, :pass => { :password => 'test_pass', :password_confirmation => 'test_pass' }
    assert_redirect
    assert_equal flash[:notice], 'You are already registered.  Please log in.'


    #MES- A slightly different case.  In the above test, the
    # confirmation URL couldn't be used immediately to make the
    # changes, due to a conflicting login.  If there IS no conflict
    # (i.e. if the info in the URL can be used as-is), the changes
    # should take place immediately, no follow on confirmation email
    # should be sent (we don't want an infinite loop!)
    usr = User.create_user_from_email_address('anothernewemail@newemail.com', users(:bob))
    put :register, :id => usr.id, :user => {:real_name => 'another test real name', :login => 'another_login_for_newemail', :time_zone => 'US/Pacific', 'zipcode' => User::INTL_USER_ZIPCODE_STR }, :pass => { :password => 'test_pass', :password_confirmation => 'test_pass' }, "intl" => "1"
    m = @emails[1].plaintext_body.match(/\/users\/register\/#{usr.id}\?(.*)$/)
    qs_map = m[1].querystring_to_map
    qs_map[:id] = usr.id
    get :register, qs_map
    assert_redirect
    assert_equal 2, @emails.length  #MES- Same length as before
    another_u = User.authenticate('another_login_for_newemail', 'test_pass')
    assert !another_u.nil?
    assert another_u.registered?
    #MES- This user should be 'international'
    assert another_u.international?

  end

  def test_edit_privacy
    post :login, "user" => { "login" => "bob", "password" => "atest" }
    assert_session_has "user_id"

    post :edit_privacy,
      "security_atts" => { "#{UserAttribute::ATT_REAL_NAME_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PUBLIC,
                           "#{UserAttribute::ATT_EMAIL_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE,
                           "#{UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PRIVATE,
                           "#{UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE,
                           "#{UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE,
                           "#{UserAttribute::ATT_GENDER_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_FRIENDS },
      'user' => { "my_plans_privacy" => SkobeeConstants::PRIVACY_LEVEL_PUBLIC }

    #KS- make sure the settings took hold in the db
    user_in_db = User.find(@response.session['user_id'])

    assert_equal SkobeeConstants::PRIVACY_LEVEL_PUBLIC, user_in_db.planner.visibility_type
    assert_equal SkobeeConstants::PRIVACY_LEVEL_PUBLIC, user_in_db.get_att_value(UserAttribute::ATT_SECURITY, UserAttribute::ATT_REAL_NAME_SECURITY_GROUP).to_i
    assert_equal SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE, user_in_db.get_att_value(UserAttribute::ATT_SECURITY, UserAttribute::ATT_EMAIL_SECURITY_GROUP).to_i
    assert_equal SkobeeConstants::PRIVACY_LEVEL_PRIVATE, user_in_db.get_att_value(UserAttribute::ATT_SECURITY, UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP).to_i
    assert_equal SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE, user_in_db.get_att_value(UserAttribute::ATT_SECURITY, UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP).to_i
    assert_equal SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE, user_in_db.get_att_value(UserAttribute::ATT_SECURITY, UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP).to_i
    assert_equal SkobeeConstants::PRIVACY_LEVEL_FRIENDS, user_in_db.get_att_value(UserAttribute::ATT_SECURITY, UserAttribute::ATT_GENDER_SECURITY_GROUP).to_i

    #KS- make everything as public as possible, see if a random user can see it
    post :edit_privacy,
      "security_atts" => { "#{UserAttribute::ATT_REAL_NAME_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PUBLIC,
                           "#{UserAttribute::ATT_EMAIL_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PUBLIC,
                           "#{UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PUBLIC,
                           "#{UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PUBLIC,
                           "#{UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE,
                           "#{UserAttribute::ATT_GENDER_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PUBLIC },
      'user' => { "my_plans_privacy" => SkobeeConstants::PRIVACY_LEVEL_PUBLIC }

    #KS- set the actual values in the db
    current_user = User.find(1)
    current_user.set_att(UserAttribute::ATT_GENDER, UserAttribute::GENDER_MALE)
    current_user.set_att(UserAttribute::ATT_RELATIONSHIP_STATUS, UserAttribute::RELATIONSHIP_TYPE_SINGLE)
    current_user.set_att(UserAttribute::ATT_BIRTH_DAY, Time.now.day)
    current_user.set_att(UserAttribute::ATT_BIRTH_MONTH, Time.now.month)
    current_user.set_att(UserAttribute::ATT_BIRTH_YEAR, Time.now.year - 20)
    current_user.description = "a dude"
    current_user.save

    #KS- login as a random user, see how much you can see
    bob_id = current_user.id
    logout
    login('x_dummy_user_2', 'atest')

    get_to_controller(PlannersController.new, 'show', { :id => 1 })
    assert_tag :tag => 'h3', :content => 'About Me'
    assert_tag :tag => 'dt', :content => 'Gender'
    assert_tag :tag => 'dd', :content => 'male'
    assert_tag :tag => 'dt', :content => 'Are They Single?'
    assert_tag :tag => 'dd', :content => 'yes'
    assert_tag :tag => 'dt', :content => 'Age'
    assert_tag :tag => 'dd', :content => '20'
    assert_tag :tag => 'dt', :content => 'Description'
    assert_tag :tag => 'dd', :content => 'a dude'

    #KS- log back in as bob, set everything to private and see what can be seen
    logout
    login
    post :edit_privacy,
      "security_atts" => { "#{UserAttribute::ATT_REAL_NAME_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PRIVATE,
                           "#{UserAttribute::ATT_EMAIL_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PRIVATE,
                           "#{UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PRIVATE,
                           "#{UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PRIVATE,
                           "#{UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PRIVATE,
                           "#{UserAttribute::ATT_GENDER_SECURITY_GROUP}" => SkobeeConstants::PRIVACY_LEVEL_PRIVATE },
      'user' => { "my_plans_privacy" => SkobeeConstants::PRIVACY_LEVEL_PUBLIC }

    logout
    login('x_dummy_user_2', 'atest')

    get_to_controller(PlannersController.new, 'show', { :id => 1 })
    assert_no_tag :tag => 'h3', :content => 'About Me'
    assert_no_tag :tag => 'dt', :content => 'Gender'
    assert_no_tag :tag => 'dd', :content => 'male'
    assert_no_tag :tag => 'dt', :content => 'Are They Single?'
    assert_no_tag :tag => 'dd', :content => 'yes'
    assert_no_tag :tag => 'dt', :content => 'Age'
    assert_no_tag :tag => 'dd', :content => '20'
    assert_no_tag :tag => 'dt', :content => 'Description'
    assert_no_tag :tag => 'dd', :content => 'a dude'

    #MGS- adding XHTML validation
    get :edit_privacy
    assert_valid_markup
  end

  def test_edit_profile
    post :login, "user" => { "login" => "bob", "password" => "atest" }
    assert_session_has "user_id"

    #KS- make sure birthday and gender are not set
    user_in_db = User.find(@response.session['user_id'])
    assert_nil user_in_db.age
    post :edit_profile,
      "user_atts" => { "#{UserAttribute::ATT_BIRTH_YEAR}" => '',
                       "#{UserAttribute::ATT_GENDER}" => UserAttribute::GENDER_UNKNOWN.to_s,
                       "#{UserAttribute::ATT_RELATIONSHIP_STATUS}" => UserAttribute::RELATIONSHIP_TYPE_UNKNOWN.to_s,
                     },
      'user' => { "real_name" => "asdf fdsa", "description" => "my description", "zipcode" => "94103" }
    user_in_db = User.find(@response.session['user_id'])
    assert_nil user_in_db.age
    assert_nil user_in_db.get_att_value(UserAttribute::ATT_GENDER)
    assert_nil user_in_db.get_att_value(UserAttribute::ATT_RELATIONSHIP_STATUS)

    post :edit_profile,
      "user_atts" => { "#{UserAttribute::ATT_BIRTH_YEAR}" => (Time.now().year - 26).to_s,
                       "#{UserAttribute::ATT_BIRTH_MONTH}" => Time.now().month.to_s,
                       "#{UserAttribute::ATT_BIRTH_DAY}" => Time.now().day.to_s,
                       "#{UserAttribute::ATT_GENDER}" => UserAttribute::GENDER_MALE.to_s,
                       "#{UserAttribute::ATT_RELATIONSHIP_STATUS}" => UserAttribute::RELATIONSHIP_TYPE_SINGLE.to_s
                     },
      'user' => { "real_name" => "asdf fdsa", "description" => "my description", "zipcode" => "94103" }

    #KS- make sure they were redirected
    assert_redirected_to :controller => "planners", :action => "show"
    match = /updated successfully/i =~ flash[:notice]
    assert_not_nil match

    #KS- check out the info in the db
    user_in_db = User.find(@response.session['user_id'])
    assert_equal "asdf fdsa", user_in_db.real_name
    assert_equal "94103", user_in_db.zipcode
    assert_equal "my description", user_in_db.description
    assert_equal 26, user_in_db.age
    assert_equal UserAttribute::GENDER_MALE, user_in_db.get_att_value(UserAttribute::ATT_GENDER).to_i
    assert_equal UserAttribute::RELATIONSHIP_TYPE_SINGLE, user_in_db.get_att_value(UserAttribute::ATT_RELATIONSHIP_STATUS).to_i

    #KS- email should not have changed (it's not an input in the edit profile screen)
    assert_equal "bob@test.com", user_in_db.email

    #KS- set gender and relationship status to rather not say (should blow it away in the db)
    post :edit_profile,
      "user_atts" => { "#{UserAttribute::ATT_BIRTH_YEAR}" => (Time.now().year - 26).to_s,
                       "#{UserAttribute::ATT_BIRTH_MONTH}" => Time.now().month.to_s,
                       "#{UserAttribute::ATT_BIRTH_DAY}" => Time.now().day.to_s,
                       "#{UserAttribute::ATT_GENDER}" => UserAttribute::GENDER_UNKNOWN.to_s,
                       "#{UserAttribute::ATT_RELATIONSHIP_STATUS}" => UserAttribute::RELATIONSHIP_TYPE_UNKNOWN.to_s
                     },
      'user' => { "real_name" => "asdf fdsa", "description" => "my description", "zipcode" => "94103" }

    #KS- make sure they were redirected
    assert_redirected_to :controller => "planners", :action => "show"
    match = /updated successfully/i =~ flash[:notice]
    assert_not_nil match

    #KS- shouldn't be any info on gender or relationship status in the db
    user_in_db = User.find(@response.session['user_id'])
    assert_nil user_in_db.get_att_value(UserAttribute::ATT_GENDER)
    assert_nil user_in_db.get_att_value(UserAttribute::ATT_RELATIONSHIP_STATUS)

    #KS- make sure a bad birth year kills it
    post :edit_profile,
      "user_atts" => { "#{UserAttribute::ATT_BIRTH_YEAR}" => "asd",
                       "#{UserAttribute::ATT_BIRTH_MONTH}" => Time.now().month.to_s,
                       "#{UserAttribute::ATT_BIRTH_DAY}" => Time.now().day.to_s,
                       "#{UserAttribute::ATT_GENDER}" => UserAttribute::GENDER_MALE.to_s
                     },
      'user' => { "real_name" => "asdf fdsa", "description" => "my description", "zipcode" => "94103" }
    assert_tag :tag => 'div', :content => /Birthday/
    user_in_db = User.find(@response.session['user_id'])
    assert_equal 26, user_in_db.age

    #KS- make sure a bad zipcode kills it
    post :edit_profile,
      "user_atts" => { "#{UserAttribute::ATT_BIRTH_YEAR}" => (Time.now().year - 26).to_s,
                       "#{UserAttribute::ATT_BIRTH_MONTH}" => Time.now().month.to_s,
                       "#{UserAttribute::ATT_BIRTH_DAY}" => Time.now().day.to_s,
                       "#{UserAttribute::ATT_GENDER}" => UserAttribute::GENDER_MALE.to_s
                     },
      'user' => { "real_name" => "asdf fdsa", "description" => "my description", "zipcode" => "9410" }
    assert_tag :tag => 'div', :content => /Zipcode/
    user_in_db = User.find(@response.session['user_id'])
    assert_equal "94103", user_in_db.zipcode

    #KS- make sure a blank zipcode kills it
    post :edit_profile,
      "user_atts" => { "#{UserAttribute::ATT_BIRTH_YEAR}" => (Time.now().year - 26).to_s,
                       "#{UserAttribute::ATT_BIRTH_MONTH}" => Time.now().month.to_s,
                       "#{UserAttribute::ATT_BIRTH_DAY}" => Time.now().day.to_s,
                       "#{UserAttribute::ATT_GENDER}" => UserAttribute::GENDER_MALE.to_s
                     },
      'user' => { "real_name" => "asdf fdsa", "description" => "my description", "zipcode" => "" }
    assert_tag :tag => 'div', :content => /Zipcode/
    user_in_db = User.find(@response.session['user_id'])
    assert_equal "94103", user_in_db.zipcode

    #KS- make sure a blank bday is cool
    post :edit_profile,
      "user_atts" => { "#{UserAttribute::ATT_BIRTH_YEAR}" => '',
                       "#{UserAttribute::ATT_BIRTH_MONTH}" => Time.now().month.to_s,
                       "#{UserAttribute::ATT_BIRTH_DAY}" => Time.now().day.to_s,
                       "#{UserAttribute::ATT_GENDER}" => UserAttribute::GENDER_MALE.to_s
                     },
      'user' => { "real_name" => "asdf fdsa", "description" => "my description", "zipcode" => "94105" }
    user_in_db = User.find(@response.session['user_id'])
    assert_equal "94105", user_in_db.zipcode
    assert_equal nil, user_in_db.age
    assert_redirected_to :controller => "planners", :action => "show"
    match = /updated successfully/i =~ flash[:notice]
    assert_not_nil match

    #MGS- adding XHTML validation
    get :edit_profile
    assert_valid_markup
  end

  def test_edit_email_password
    post :login, "user" => { "login" => "bob", "password" => "atest" }
    assert_session_has "user_id"

    post :logout
    post :login, "user" => { "login" => "bob", "password" => "atest" }
    assert_session_has "user_id"

    #KS- change the password
    post :edit_password, "user" => { "current_password" => "atest", "password" => "atest2", "password_confirmation" => "atest2", "form" => "change_password" }

    user_to_verify = User.find_by_string("bob")

    #KS- assert we can get back in with the new password
    post :logout
    post :login, "user" => { "login" => "bob", "password" => "atest2" }
    assert_session_has "user_id"

    #KS- try submitting with a typo in password confirm
    post :edit_password, "user" => { "current_password" => "atest2", "password" => "asdfasdf", "password_confirmation" => "fdsafdsa", "form" => "change_password" }

    #KS- assert that we can get back in with the previous password (new one should not take effect)
    post :logout
    post :login, "user" => { "login" => "bob", "password" => "atest2" }
    assert_session_has "user_id"

    #KS- try submitting with the wrong current password
    post :edit_password, "user" => { "current_password" => "fark", "password" => "asdfasdf", "password_confirmation" => "asdfasdf", "form" => "change_password" }

    #KS- assert that we can get back in with the previous password (new one should not take effect)
    post :logout
    post :login, "user" => { "login" => "bob", "password" => "atest2" }
    assert_session_has "user_id"
  end

  def test_edit_login
    login

    #MES- Can we see the edit_login page?
    get :edit_login
    assert_success

    #MES- Try to change the login to a new string
    post :edit_login, "user" => { "login" => "new_login_for_bob" }
    assert_redirect

    #MES- We should be able to log in using the new login
    logout
    login 'new_login_for_bob', 'atest'

    #MES- Try to change the login to an existing login
    post :edit_login, "user" => { "login" => "existingbob" }
    #MES- We should NOT be redirected
    assert_success
  end

  def test_delete
    ActionMailer::Base.deliveries = []

    # Immediate delete
    post :login, "user" => { "login" => "deletebob1", "password" => "alongtest" }
    assert_session_has "user_id"
    assert_equal 0, ActionMailer::Base.deliveries.size

    UserSystem::CONFIG[:delayed_delete] = false
    post :delete, "user" => { "form" => "delete" }
    assert_equal 1, ActionMailer::Base.deliveries.size

    assert_session_has_no "user_id"
    post :login, "user" => { "login" => "deletebob1", "password" => "alongtest" }
    assert_session_has_no "user_id"

    # Now try delayed delete
    ActionMailer::Base.deliveries = []

    post :login, "user" => { "login" => "deletebob2", "password" => "alongtest" }
    assert_session_has "user_id"

    UserSystem::CONFIG[:delayed_delete] = true
    post :delete, "user" => { "form" => "delete" }
    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries[0]
    body = mail.plaintext_body
    m = body.match(/user_id=([0-9]*)&key=([A-Za-z0-9]*)/)
    id = m[1]
    key = m[2]
    post :restore_deleted, "user_id" => "#{id}", "key" => "badkey"
    assert_session_has_no "user_id"

    # Advance the time past the delete date
    Time.set_advance_by_days(UserSystem::CONFIG[:delayed_delete_days]) do
      post :restore_deleted, "user_id" => "#{id}", "key" => "#{key}"
      assert_session_has_no "user_id"
    end

    post :restore_deleted, "user_id" => "#{id}", "key" => "#{key}"
    assert_session_has "user_id"
    get :logout
  end

  def test_bad_screen_name
    post :signup, "user" => { "login" => "new(bob", "email" => "newbob@test.com" }, "pass" => { "password" => "newpassword", "password_confirmation" => "newpassword" }
    assert_session_has_no "user_id"
    assert_equal 0, ActionMailer::Base.deliveries.size

    post :signup, "user" => { "login" => ")newbob", "email" => "newbob@test.com" }, "pass" => { "password" => "newpassword", "password_confirmation" => "newpassword" }
    assert_session_has_no "user_id"
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_bad_real_name
    post :signup, "user" => { "login" => "newbob", "real_name" => "(stuff", "email" => "newbob@test.com" }, "pass" => { "password" => "newpassword", "password_confirmation" => "newpassword" }
    assert_session_has_no "user_id"
    assert_equal 0, ActionMailer::Base.deliveries.size

    post :signup, "user" => { "login" => "newbob", "real_name" => "st)uff", "email" => "newbob@test.com" }, "pass" => { "password" => "newpassword", "password_confirmation" => "newpassword" }
    assert_session_has_no "user_id"
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def do_change_password(bad_password, bad_email)
    ActionMailer::Base.deliveries = []

    post :login, "user" => { "login" => "bob", "password" => "atest" }
    assert_session_has "user_id"

    if not bad_password and not bad_email
      post :edit_password, "user" => { "current_password" => "atest", "password" => "changed_password", "password_confirmation" => "changed_password" }

      #KS- we're removing the changed password email, so make sure no email is sent
      assert_equal 0, ActionMailer::Base.deliveries.size
    elsif bad_password
      post :edit_password, "user" => { "current_password" => "atest", "password" => "bad", "password_confirmation" => "bad" }
      assert_invalid_column_on_record "user", "password"
      assert_success
      assert_equal 0, ActionMailer::Base.deliveries.size
    elsif bad_email
      ActionMailer::Base.inject_one_error = true
      post :edit_password, "user" => { "current_password" => "atest", "password" => "changed_password", "password_confirmation" => "changed_password" }
      assert_equal 0, ActionMailer::Base.deliveries.size
    else
      # Invalid test case
      assert false
    end

    get :logout
    assert_session_has_no "user_id"

    if not bad_password
      post :login, "user" => { "login" => "bob", "password" => "changed_password" }
      assert_session_has "user_id"
      post :edit_password, "user" => { "current_password" => "changed_password", "password" => "atest", "password_confirmation" => "atest" }
      get :logout
    end

    post :login, "user" => { "login" => "bob", "password" => "atest" }
    assert_session_has "user_id"

    get :logout
  end

  def test_change_password
    do_change_password(false, false)
    do_change_password(true, false)
    do_change_password(false, true)
  end

  def do_forgot_password(bad_address, bad_email)
    ActionMailer::Base.deliveries = []

    #MES- Get the user object
    user = users(:bob)

    password = "anewpassword"
    @request.session['return-to'] = "/bogus/location"
    if not bad_address and not bad_email
      #MES- Go to the "forgot password" URL
      post :forgot_password, "user" => { "email" => "bob@test.com" }

      #MES- This should have delivered an email to bob
      assert_equal 1, ActionMailer::Base.deliveries.size
      mail = ActionMailer::Base.deliveries[0]
      assert_equal "bob@test.com", mail.to_addrs[0].to_s
      #MES- Get the info out of the email
      m = mail.plaintext_body.match(/user_id=(.*)&key=(.*)/)
      id = m[1]
      key = m[2]
      #MES- And post the new password with the info from the email
      post :edit_password, "user" => { "password" => "#{password}", "password_confirmation" => "#{password}" }, "user_id" => "#{id}", "key" => "#{key}"

      #MES- Resetting the password should log the user in
      assert_session_has "user_id"
      get :logout
    elsif bad_address
      post :forgot_password, "user" => { "email" => "bademail@test.com" }
      assert_equal 0, ActionMailer::Base.deliveries.size
    elsif bad_email
      ActionMailer::Base.inject_one_error = true
      post :forgot_password, "user" => { "email" => "bob@test.com" }
      assert_equal 0, ActionMailer::Base.deliveries.size
    else
      # Invalid test case
      assert false
    end

    if not bad_address and not bad_email
      post :login, "user" => { "login" => "bob", "password" => "#{password}" }
    else
      # Okay, make sure the database did not get changed
      get :logout
      post :login, "user" => { "login" => "bob", "password" => "atest" }
    end

    assert_session_has "user_id"

    # Put the old settings back
    if not bad_address
      post :edit_password, "user" => {"current_password" => "#{password}",  "password" => "atest", "password_confirmation" => "atest" }
    end

    get :logout
  end

  def test_forgot_password
    do_forgot_password(false, false)
    do_forgot_password(true, false)
    do_forgot_password(false, true)
  end

  def test_bad_signup
    @request.session['return-to'] = "/bogus/location"

    post :signup, "user" => { "login" => "newbob", "zipcode" => "94111" }, "pass" => { "password" => "newpassword", "password_confirmation" => "wrong" }
    assert_invalid_column_on_record "user", "password"
    assert_success

    post :signup, "user" => { "login" => "yo", "zipcode" => "94111" }, "pass" => { "password" => "newpassword", "password_confirmation" => "newpassword" }
    assert_invalid_column_on_record "user", "login"
    assert_success

    post :signup, "user" => { "login" => "yo", "zipcode" => "94111" }, "pass" => { "password" => "newpassword", "password_confirmation" => "wrong" }
    assert_invalid_column_on_record "user", ["login", "password"]
    assert_success
  end

  def test_invalid_login
    post :login, "user" => { "login" => "bob", "password" => "not_correct" }

    assert_session_has_no "user_id"

    assert_template_has "login"
  end

  def test_login_logoff

    post :login, "user" => { "login" => "bob", "password" => "atest" }
    assert_session_has "user_id"

    get :logout
    assert_template 'logout'
    assert_session_has_no "user_id"

    #KS: should be able to log in using email
    post :login, "user" => { "login" => "bob@test.com", "password" => "atest" }
    assert_session_has "user_id"

    get :logout
    assert_template 'logout'
    assert_session_has_no "user_id"

  end

  def test_remember_me
    #MES- On the login page, the 'remember me' checkbox should set a cookie
    # that lets them get in later.
    post :login, "user" => { "login" => "bob", "password" => "atest", :remember_me => "1" }
    token = @response.cookies['token']
    user_id = @response.cookies['user_id']

    #MES- Check that that user can be logged in with that token
    usr = User.authenticate_by_token(user_id, token)
    assert_not_nil usr

    #MGS- cheap way to logoff
    @request.session['user_id'] = nil
    @request.session['conditions'] = nil
    @request.user_obj = nil

    #MGS- check that we are logged off by requesting a login_required action
    get :edit_privacy
    assert_redirected_to "/users/login"

    #MGS- get new request and response objects, to make sure we aren't sharing the same session
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
    assert @request.cookies.empty?
    #MGS- now set the 'remember me' cookies back
    @request.cookies = { 'token' => token, 'user_id' => user_id }

    #MGS- requesting the splash controller with a valid login cookie, should log
    # the user in automatically and redirect to the dashboard
    get_to_controller(SplashController.new, 'index')
    assert_redirected_to "/planners/dashboard"

    #MGS- request another logged in action to ensure logged in automatically
    get :edit_privacy
    assert_template 'edit_privacy'
  end

  def test_contacts
    login users(:friend_2_of_user)

    get :contacts
    assert_response :success, "Viewing contacts while logged in failed"
    assert_template 'contacts', "The contacts view should use the contacts template"
    assert_tag :tag=> "a", :content=> users(:unregistered_user).login, :ancestor => {:tag=>"div", :attributes =>{:id=>"content"}}

    assert_no_tag :tag=> "a", :content=> users(:user_with_friends_and_private_cal).login, :ancestor => {:tag=>"div", :attributes =>{:id=>"content"}}
    assert_no_tag :tag=> "a", :content=> users(:user_with_friends_and_friends_cal).login, :ancestor => {:tag=>"div", :attributes =>{:id=>"content"}}
    assert_no_tag :tag=> "a", :content=> users(:existingbob).login, :ancestor => {:tag=>"div", :attributes =>{:id=>"content"}}
    assert_no_tag :tag=> "a", :content=> users(:user_with_friends).login, :ancestor => {:tag=>"div", :attributes =>{:id=>"content"}}

    assert_valid_markup


    get :contacts_inverse
    assert_response :success, "Viewing contacts while logged in failed"
    assert_template 'contacts_inverse', "The contacts view should use the contacts template"
    assert_no_tag :tag=> "a", :content=> users(:unregistered_user).login, :ancestor => {:tag=>"div", :attributes =>{:id=>"content"}}

    assert_tag :tag=> "a", :content=> users(:user_with_friends_and_private_cal).login, :ancestor => {:tag=>"div", :attributes =>{:id=>"content"}}
    assert_tag :tag=> "a", :content=> users(:user_with_friends_and_friends_cal).login, :ancestor => {:tag=>"div", :attributes =>{:id=>"content"}}
    assert_tag :tag=> "a", :content=> users(:existingbob).login, :ancestor => {:tag=>"div", :attributes =>{:id=>"content"}}
    assert_tag :tag=> "a", :content=> users(:user_with_friends).login, :ancestor => {:tag=>"div", :attributes =>{:id=>"content"}}

    assert_valid_markup
  end

  def test_directions_from_home
    helper_test_directions 'directions_from_loc', "500 sansome san francisco, ca 94111"
  end

  def helper_test_directions (action, address)
    login

    #MES- We should be able to set the address for the user; checkboxes have a default value of 'on'
    post action, :directions_place_id => places(:first_place).id, :location => address

    #TODO: make sure the redirect redirected to google
    assert_redirect
  end

  def test_contact_search
    #MGS- better testing is in watir tests
    login users(:friend_1_of_user)
    get 'search', :q => "Bob"
    assert_tag :tag => 'div', :content => users(:bob).login

    #MGS- adding XHTML validation
    assert_valid_markup
  end

  def test_change_friend_status
    login users(:friend_1_of_user)

    #MGS- Before the test, the user :friend_1_of_user does not
    # consider user :user_with_friends a friend or contact, but
    # the reverse connection IS a friend
    usr = users(:friend_1_of_user)
    no_contact = users(:user_with_friends)
    assert !usr.contacts.include?(no_contact), ':user_with_friends is (incorrectly) a contact of :friend_1_of_user at the beginning of the test'

    #KS- make sure we set their friend update notification to always on so we get the notifications
    no_contact.set_att(UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_OPTION, UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_ALWAYS)

    #KS- make sure no email's been sent yet
    assert_equal 0, @emails.length

    relationship_existed = usr.relationship_exists(users(:user_with_friends).id)

    #MGS- Calling change_friend_status in the User controller
    # should convert an unaffiliated user into a contact, and should
    # render the list of users that aren't affiliated.
    get 'change_friend_status', :contact_id => users(:user_with_friends).id, :friend_status => User::FRIEND_STATUS_CONTACT

    #KS- make sure the contacts were set properly
    usr = User.find(users(:friend_1_of_user).id)
    should_be_contact = User.find(users(:user_with_friends).id)
    assert !usr.friends.include?(should_be_contact), ':user_with_friends IS a friend of :user_with_friends after calling change_friend_status'
    assert usr.friend_contacts.include?(should_be_contact),  ':user_with_friends is not a friend_contact of :user_with_friends after calling change_friend_status'

    #KS- a friend notification email should have been sent
    assert_equal 1, @emails.length

    #KS- make sure they don't get a notification email when the friend status is set again
    get 'change_friend_status', :contact_id => users(:user_with_friends).id, :friend_status => User::FRIEND_STATUS_NONE
    assert_equal 1, @emails.length
    get 'change_friend_status', :contact_id => users(:user_with_friends).id, :friend_status => User::FRIEND_STATUS_FRIEND
    assert_equal 1, @emails.length

    #KS- make sure a notification email DOESN'T get sent when the friend notification is off
    no_contact.set_att(UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_OPTION, UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_NEVER)

    #KS- set the friend status back to nothing so we can change it back again
    get 'change_friend_status', :contact_id => users(:user_with_friends).id, :friend_status => User::FRIEND_STATUS_NONE

    #KS- change the person to a friend
    get 'change_friend_status', :contact_id => users(:user_with_friends).id, :friend_status => User::FRIEND_STATUS_FRIEND

    #KS- shouldn't have gotten another email
    assert_equal 1, @emails.length
  end

  def register_unregistered_user(usr)
    logout
    @emails.clear
    put :register, :id => usr.id, :user => {:real_name => 'another test real name', :login => 'another_login_for_newemail', :zipcode => '94101' }, :pass => { :password => 'test_pass', :password_confirmation => 'test_pass' }
    m = @emails[0].plaintext_body.match(/\/users\/register\/#{usr.id}\?(.*)$/)
    qs_map = m[1].querystring_to_map
    qs_map[:id] = usr.id
    get :register, qs_map
    assert_redirect
    usr = User.find(usr.id)
    assert usr.registered?
  end

  def test_unregistered_user_doesnt_get_friend_notifications
    #KS- created an unregistered_user
    unregistered_user = User.create_user_from_email_address('newemail@newemail.com', users(:bob))
    assert !unregistered_user.registered?

    #KS- login existingbob and add unregistered_user as a friend of existingbob's
    login('longbob', 'alongtest')
    get 'change_friend_status', :contact_id => unregistered_user.id, :friend_status => User::FRIEND_STATUS_CONTACT

    #KS- make sure the contacts were set properly
    usr = User.find(users(:longbob).id)
    should_be_contact = User.find(unregistered_user.id)
    assert !usr.friends.include?(should_be_contact), ':user_with_friends IS a friend of :user_with_friends after calling change_friend_status'
    assert usr.friend_contacts.include?(should_be_contact),  ':user_with_friends is not a friend_contact of :user_with_friends after calling change_friend_status'

    #KS- a friend notification email should NOT have been sent
    assert_equal 0, @emails.length

    #KS- have unregistered_user register
    register_unregistered_user(unregistered_user)

    #KS- login longbob and have him add unregistered_user as a contact
    logout
    login('deletebob1', 'alongtest')
    @emails.clear
    get 'change_friend_status', :contact_id => unregistered_user.id, :friend_status => User::FRIEND_STATUS_CONTACT

    #KS- a friend notification email SHOULD have been sent
    assert_equal 1, @emails.length
  end

  def test_unregistered_user_reminder_hours
    #KS- created an unregistered_user
    unregistered_user = User.create_user_from_email_address('newemail@newemail.com', users(:bob))
    assert !unregistered_user.registered?

    #KS- test reminder hours for an unregistered user is initially set to 1
    unregistered_user = User.find(unregistered_user.id)
    assert_equal 1, unregistered_user.get_att_value(UserAttribute::ATT_REMINDER_HOURS)

    #KS- have unregistered_user register
    register_unregistered_user(unregistered_user)

    #KS- upon registration, reminder hours should be set to 6
    unregistered_user = User.find(unregistered_user.id)
    assert_equal 6, unregistered_user.get_att_value(UserAttribute::ATT_REMINDER_HOURS)
  end

  def test_settings
    login
    get :settings
    assert_valid_markup
  end

  def test_edit_email
    login
    get :edit_email
    assert_valid_markup
  end

  def test_edit_password
    login
    get :edit_password
    assert_valid_markup
  end

  def test_edit_notifications
    login

    #KS- set everything to default
    user = User.find(users(:bob).id)
    user.set_notifications_to_default
    user.save
    user = User.find(users(:bob).id)
    assert_equal UserAttribute::TRUE_USER_ATT_VALUE, user.get_att_value(UserAttribute::ATT_REMIND_BY_EMAIL)
    assert_equal UserAttribute::INVITE_NOTIFICATION_ALWAYS, user.get_att_value(UserAttribute::ATT_INVITE_NOTIFICATION_OPTION)
    assert_equal UserAttribute::PLAN_MODIFIED_ALWAYS, user.get_att_value(UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION)
    assert_equal UserAttribute::CONFIRMED_PLAN_REMINDER_ALWAYS, user.get_att_value(UserAttribute::ATT_CONFIRMED_PLAN_REMINDER_OPTION)
    assert_equal UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_ALWAYS, user.get_att_value(UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_OPTION)
    assert_equal UserAttribute::TRUE_USER_ATT_VALUE, user.get_att_value(UserAttribute::ATT_USER_COMMENTED_NOTIFICATION_OPTION)

    #KS- turn everything off
    post :edit_notifications,
         :user_atts => {
          UserAttribute::ATT_INVITE_NOTIFICATION_OPTION => UserAttribute::INVITE_NOTIFICATION_NEVER,
          UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION => UserAttribute::PLAN_MODIFIED_NEVER,
          UserAttribute::ATT_CONFIRMED_PLAN_REMINDER_OPTION => UserAttribute::CONFIRMED_PLAN_REMINDER_NEVER,
          UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_OPTION => UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_NEVER,
          UserAttribute::ATT_USER_COMMENTED_NOTIFICATION_OPTION => UserAttribute::FALSE_USER_ATT_VALUE
         }

    #KS- make sure remind by email is still on, and everything else is off
    user = User.find(users(:bob).id)
    assert_equal UserAttribute::TRUE_USER_ATT_VALUE, user.get_att_value(UserAttribute::ATT_REMIND_BY_EMAIL)
    assert_equal UserAttribute::INVITE_NOTIFICATION_NEVER, user.get_att_value(UserAttribute::ATT_INVITE_NOTIFICATION_OPTION)
    assert_equal UserAttribute::PLAN_MODIFIED_NEVER, user.get_att_value(UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION)
    assert_equal UserAttribute::CONFIRMED_PLAN_REMINDER_NEVER, user.get_att_value(UserAttribute::ATT_CONFIRMED_PLAN_REMINDER_OPTION)
    assert_equal UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_NEVER, user.get_att_value(UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_OPTION)
    assert_equal UserAttribute::FALSE_USER_ATT_VALUE, user.get_att_value(UserAttribute::ATT_USER_COMMENTED_NOTIFICATION_OPTION)

    get :edit_notifications
    assert_valid_markup
  end

  def test_forgot_password_markup
    login
    get :forgot_password
    assert_valid_markup
  end

  def test_invite
    login
    #MES- Create an unregistered user
    usr = User.create_user_from_email_address('newemail@newemail.com', users(:bob))

    #MES- We should be able to see the invite page
    get :invite, :id => usr.id
    assert_success
    assert_valid_markup

    #MES- Send an email
    post :invite, :id => usr.id, :invite_subject => 'test subject', :invite_body => 'test <b>body</b>'
    assert_equal 1, @emails.length
    #MES- NOTE: We USED to test that the "from" of the email was bob's email address.
    # This is now removed- all Skobee emails are sent from a Skobee email address, so
    # that spam filters don't think that it's junk mail (i.e. so that we pass SPF tests.)

    #MES- The subject should be what we specified
    email = @emails[0]
    assert_equal 'test subject', email.subject
    #MES- The body should contain what we specified- the HTML body should
    # contain the stuff HTML encoded
    assert !email.plaintext_body.match(/test <b>body<\/b>/).nil?
    assert !email.html_body.match(/test &lt;b&gt;body&lt;\/b&gt;/).nil?
  end

  def create_plan(name, date)
    #KS- calculate date details from date
    day_of_month = date.day
    month = date.month
    year = date.year
    hour = date.hour
    meridian = 'AM'
    if hour > 12
      meridian = 'PM'
      hour -= 12
    elsif hour == 12
      meridian = 'PM'
    elsif hour == 0
      meridian = 'AM'
      hour = 12
    end

    #KS- create a plan starting on date
    post_to_controller(PlansController.new, :create, { 'plan' => {'name' => name},
                                                       'dateperiod' => '0',
                                                       'timeperiod' => '0',
                                                       'hiddendate' => "#{year}-#{month}-#{day_of_month}",
                                                       'date_month' => "#{month}",
                                                       'date_day' => "#{day_of_month}",
                                                       'date_year' => "#{year}",
                                                       'plan_hour' => "#{hour}",
                                                       'plan_min' => '00',
                                                       'plan_meridian' => "#{meridian}",
                                                       'place_id' => '1',
                                                       'place_origin' => '0'
                                                      })

    #KS- make sure the plan got created
    plan = Plan.find(:first, :conditions => [ 'name = :name', {:name => name}])
    assert_not_nil plan

    return plan
  end

  def create_confirmed_user(login, email, password)
    #KS- logout before doing the create
    logout

    post :signup,
         :user => {:real_name => 'asdf',
                   :login => login,
                   :email => email,
                   :zipcode => '94101'},
         :pass => {:password => password, :password_confirmation => password}

    #KS- confirm the user the el-cheapo way
    new_user = User.find(:first, :conditions => [ 'login = :login', {:login => login} ])
    new_user.verified = 1
    new_user.save

    return new_user
  end

  #KS- create a fresh user with one plan (easier to deal with in this case than putzing around with fixtures)
  def reminder_setup
  #:user => {:real_name => 'test real name', :login => 'test_login_for_newemail', :zipcode => '94101' }, :pass => { :password => 'test_pass', :password_confirmation => 'test_pass' }
    post :signup,
         :user => {:real_name => 'blah',
                   :login => 'afakelogin',
                   :email => 'kavin.stewart@gmail.com',
                   :zipcode => '94105'},
         :pass => {:password => 'asdfasdf', :password_confirmation => 'asdfasdf'}

    #KS- confirm the user the el-cheapo way
    @user = User.find(:first, :conditions => [ 'login = :login', {:login => 'afakelogin'} ])
    @user.verified = 1
    @user.save

    #KS- log in
    login('afakelogin', 'asdfasdf')

    #KS- calculate a date 1 week from now
    @date_one_week_from_now = Time.now + 1.week
    @day_of_month = @date_one_week_from_now.day
    @month = @date_one_week_from_now.month
    @year = @date_one_week_from_now.year
    @hour = @date_one_week_from_now.hour
    @meridian = 'AM'
    if @hour > 12
      @meridian = 'PM'
      @hour -= 12
    elsif @hour == 12
      @meridian = 'PM'
    elsif @hour == 0
      @meridian = 'AM'
      @hour = 12
    end

    #KS- create a plan 1 week from now
    create_plan('a plan in 1 week', @date_one_week_from_now)

    #KS- make sure the plan got created
    @plan = Plan.find(:first, :conditions => [ 'name = :name', {:name => 'a plan in 1 week'}])
    assert_not_nil @plan

    #KS- clear out any emails (including confirmation)
    @emails.clear

    #KS- make sure the reminder settings are what we expect
    assert_equal UserAttribute::TRUE_USER_ATT_VALUE, @user.get_att_value(UserAttribute::ATT_REMIND_BY_EMAIL)
    assert_equal UserAttribute::CONFIRMED_PLAN_REMINDER_ALWAYS, @user.get_att_value(UserAttribute::ATT_CONFIRMED_PLAN_REMINDER_OPTION)
    assert_equal 6, @user.get_att_value(UserAttribute::ATT_REMINDER_HOURS)
  end

  def test_reminders_arent_sent_inside_reminder_window
    #KS- do plan creation stuff within time modified window -- this way the plan creation date will be within
    #the reminder window
    reminder_setup

    #KS- create a plan in 5 hours from now
    plan_in_five_hours_start = Time.now + 5.hour
    plan_in_five_hours = create_plan('plan_in_five_hours', plan_in_five_hours_start)

    #KS- make sure the plan got created
    plan_in_five_hours = Plan.find(:first, :conditions => [ 'name = :name', {:name => 'plan_in_five_hours'}])
    assert_not_nil plan_in_five_hours

    #KS- logout so we can create a new user
    logout

    #KS- should be nothing so far
    assert_equal 0, @emails.length

    #KS- create a new user
    anewfakelogin = create_confirmed_user('anewfakelogin', 'kavins@skobee.com', 'asdfasdf')

    #KS- create confirmation email
    assert_equal 1, @emails.length
    @emails.clear

    #KS- log in afakelogin and invite anewfakelogin to the plan
    login('afakelogin', 'asdfasdf')
    post_to_controller(PlansController.new, :update, { :id => plan_in_five_hours.id,
                                                       :plan_who => "anewfakelogin"
                                                      })

    #KS- invitation notification
    assert_equal 1, @emails.length
    @emails.clear

    #KS- login as anewfakelogin and accept the invitation
    logout
    login('anewfakelogin', 'asdfasdf')
    post_to_controller(PlannersController.new, :accept_plan, { :id => anewfakelogin.planner.id,
                                                               :pln_id => plan_in_five_hours.id
                                                              })

    anewfakelogin = User.find_by_string('anewfakelogin')

    #KS- set anewfakelogin's reminder window to 1 hour before the event (this way they should
    #still get a notification)
    anewfakelogin.set_att(UserAttribute::ATT_REMINDER_HOURS, 2)

    #KS- try sending reminders now, neither user we care about should get any
    User.send_reminders(sqlize_date(Time.now))
    assert_equal 0, @emails.find_all{|email| email.to[0] == @user.email}.length
    assert_equal 0, @emails.find_all{|email| email.to[0] == anewfakelogin.email}.length


    #KS- set the time to five hours before the event
    three_hours_before_event = plan_in_five_hours_start.getgm - 3.hour
    Time.set_now_gmt(three_hours_before_event.year, three_hours_before_event.month, three_hours_before_event.day, three_hours_before_event.hour) do
      #KS- make sure we have no emails sitting around before sending the reminders
      @emails.clear

      #KS- send the reminders
      User.send_reminders(sqlize_date(Time.now))

      #KS- make sure no emails came to @user because their reminder window (6 hours) is greater
      #than the time between the event creation and event start
      assert_equal 0, @emails.find_all{|email| email.to[0] == @user.email}.length

      #KS- anewfakelogin also shouldn't have gotten an email yet, because the time
      #is still outside their reminder window
      assert_equal 0, @emails.find_all{|email| email.to[0] == anewfakelogin.email}.length
    end

    #KS- set the time to one hour before the event
    one_hour_before_event = plan_in_five_hours_start.getgm - 1.hour
    Time.set_now_gmt(one_hour_before_event.year, one_hour_before_event.month, one_hour_before_event.day, one_hour_before_event.hour) do
      @emails.clear
      User.send_reminders(sqlize_date(Time.now))

      #KS- now @user should still not have gotten an email, but anewfakelogin should have gotten one
      assert_equal 0, @emails.find_all{|email| email.to[0] == @user.email}.length
      assert_equal 1, @emails.find_all{|email| email.to[0] == anewfakelogin.email}.length
    end
  end

  def sqlize_date(date)
    return "#{date.year}-#{date.month}-#{date.day} #{date.hour}:#{date.min}:00"
  end

  def test_reminder_with_multiple_accepted_invitees
    reminder_setup

    #KS- create a bunch of other plans
    create_plan('another plan', Time.now + 1.day)
    create_plan('a plan in 2 weeks', Time.now + 14.day)
    create_plan('a plan created just before start', @date_one_week_from_now)
    plan_created_just_before_start = Plan.find(:first, :conditions => ["name = :name", {:name => 'a plan created just before start'}])
    plan_created_just_before_start.created_at = (@date_one_week_from_now - 1.hours).getgm.fmt_for_mysql
    plan_created_just_before_start.save!

    #KS- logout so we can create a new user
    logout

    #KS- should be nothing so far
    assert_equal 0, @emails.length

    #KS- create a new user
    new_user = create_confirmed_user('anewfakelogin', 'kavins@skobee.com', 'asdfasdf')

    #KS- create confirmation email
    assert_equal 1, @emails.length
    @emails.clear

    #KS- log in afakelogin and invite anewfakelogin to the plan
    login('afakelogin', 'asdfasdf')
    post_to_controller(PlansController.new, :update, { :id => @plan.id,
                                                       :plan_who => "anewfakelogin"
                                                      })

    #KS- invitation notification
    assert_equal 1, @emails.length
    @emails.clear

    #KS- login as anewfakelogin and accept the invitation
    logout
    login('anewfakelogin', 'asdfasdf')
    post_to_controller(PlannersController.new, :accept_plan, { :id => new_user.planner.id,
                                                               :pln_id => @plan.id
                                                              })

    #KS- shouldn't be any emails right now
    assert_equal 0, @emails.length

    #KS- fast forward to 1 hour before the beginning of the plan
    just_after_plan_begin = @date_one_week_from_now.getgm - 1.hour
    Time.set_now_gmt(just_after_plan_begin.year, just_after_plan_begin.month, just_after_plan_begin.day, just_after_plan_begin.hour) do
      #KS- run what the reminder agent runs
      User.send_reminders(sqlize_date(Time.now))

      #KS- this is 1 because the plan created yesterday will be eliminated by the new code that stops a
      #reminder from being sent if the event creation is within the user's reminder window of the event fuzzy start
      assert_equal 1, @emails.find_all{|email| email.to[0] == @user.email}.length
      assert_equal 1, @emails.find_all{|email| email.to[0] == 'kavins@skobee.com'}.length
      @emails.clear

      #KS- next reminder should cause no notifications to be sent
      User.send_reminders(sqlize_date(Time.now))
      assert_equal 0, @emails.length
    end
  end

  def test_reminder_doesnt_send_multiple_or_early
    reminder_setup

    #KS- make sure there are no emails for this user
    @emails.clear

    #KS- shouldn't send a reminder a week in advance
    User.send_reminders
    assert_equal 0, @emails.find_all{|email| email.to[0] == @user.email}.length

    #KS- shouldn't send a reminder 7 hours beforehand (reminder hours are set to 6)
    just_outside_reminder_window = @date_one_week_from_now.getgm - 7.hours
    Time.set_now_gmt(just_outside_reminder_window.year, just_outside_reminder_window.month, just_outside_reminder_window.day, just_outside_reminder_window.hour) do
      @emails.clear

      #KS- run what the reminder agent runs
      User.send_reminders(sqlize_date(Time.now))

      #KS- there shouldn't be any yet
      assert_equal 0, @emails.find_all{|email| email.to[0] == @user.email}.length
    end

    #KS- fast forward to within 5 hours of the plan
    within_reminder_window = @date_one_week_from_now.getgm - 5.hours
    Time.set_now_gmt(within_reminder_window.year, within_reminder_window.month, within_reminder_window.day, within_reminder_window.hour) do
      @emails.clear

      #KS- run what the reminder agent runs
      User.send_reminders(sqlize_date(Time.now))

      #KS- make sure there is one and only one
      assert_equal 1, @emails.find_all{|email| email.to[0] == @user.email}.length
    end
  end

  #KS- multiple plans within one timeframe means multiple reminders
  def test_reminder_sends_one_email_per_plan
    reminder_setup

    #KS- make sure there are no emails for this user
    assert_equal 0, @emails.find_all{|email| email.to[0] == @user.email}.length

    #KS- shouldn't send a reminder a week in advance
    User.send_reminders
    assert_equal 0, @emails.find_all{|email| email.to[0] == @user.email}.length

    #KS- create another plan to be reminded of
    post_to_controller(PlansController.new, :create, { 'plan' => {'name' => 'another plan in 1 week'},
                                                       'dateperiod' => '0',
                                                       'timeperiod' => '0',
                                                       'hiddendate' => "#{@year}-#{@month}-#{@day_of_month}",
                                                       'date_month' => "#{@month}",
                                                       'date_day' => "#{@day_of_month}",
                                                       'date_year' => "#{@year}",
                                                       'plan_hour' => "#{@hour}",
                                                       'plan_min' => '00',
                                                       'plan_meridian' => "#{@meridian}",
                                                       'place_id' => '1',
                                                       'place_origin' => '0'
                                                      })

    #KS- make sure the plan got created
    other_plan = Plan.find(:first, :conditions => [ 'name = :name', {:name => 'another plan in 1 week'}])
    assert_not_nil other_plan

    #KS- fast forward to within 5 hours of the plans
    within_reminder_window = @date_one_week_from_now.getgm - 5.hours
    Time.set_now_gmt(within_reminder_window.year, within_reminder_window.month, within_reminder_window.day, within_reminder_window.hour) do
      #KS- run what the reminder agent runs
      User.send_reminders(sqlize_date(Time.now))

      #KS- grab emails to the user we give a crap about
      emails_we_care_about = @emails.find_all{|email| email.to[0] == @user.email}

      #KS- make sure there are 2 since we have multiple plans at the same time
      assert_equal 2, emails_we_care_about.length
    end
  end

  #KS- make sure the unregistered users get an email that's specific to them (not the same as the registered one)
  def test_unregistered_user_gets_different_reminder
    reminder_setup

    post_to_controller(PlansController.new, :update, {:id => @plan.id, :plan_who => "newemail@newemail.com,,"})

    #KS- fast forward to within 5 hours of the plan
    within_reminder_window = @date_one_week_from_now.getgm - 5.hours
    Time.set_now_gmt(within_reminder_window.year, within_reminder_window.month, within_reminder_window.day, within_reminder_window.hour) do
      #KS- run what the reminder agent runs
      User.send_reminders(sqlize_date(Time.now))

      #KS- grab the email we care about
      emails_to_new_user = @emails.find_all{|email| email.to[0] == "newemail@newemail.com"}
      assert_equal 1, emails_to_new_user.length

      #KS- make sure the body matches some stuff that's only in the unregistered reminder
      #and that it does NOT match some stuff that's only in the registered reminder
      unregistered_reminder_email = emails_to_new_user[0]
      assert unregistered_reminder_email.body.match(/You can also suggest a new time/)
      assert !unregistered_reminder_email.body.match(/Too many emails from Skobee/)
    end
  end

  def test_remind_only_if_remind_by_email_on
    reminder_setup

    #KS- turn off email notifications
    @user.set_att(UserAttribute::ATT_REMIND_BY_EMAIL, UserAttribute::FALSE_USER_ATT_VALUE)

    #KS- fast forward to within 5 hours of the plan
    within_reminder_window = @date_one_week_from_now.getgm - 5.hours
    Time.set_now_gmt(within_reminder_window.year, within_reminder_window.month, within_reminder_window.day, within_reminder_window.hour) do
      #KS- run what the reminder agent runs
      User.send_reminders(sqlize_date(Time.now))

      #KS- make sure there are no reminders since we turned off email notifications
      assert_equal 0, @emails.find_all{|email| email.to[0] == @user.email}.length

      #KS- run it again with REMIND_BY_EMAIL on
      @emails.clear
      @user.planner.mark_plan_notified(@plan, nil)
      @user.set_att(UserAttribute::ATT_REMIND_BY_EMAIL, UserAttribute::TRUE_USER_ATT_VALUE)
      User.send_reminders(sqlize_date(Time.now))

      #KS- make sure there is one and only one
      assert_equal 1, @emails.find_all{|email| email.to[0] == @user.email}.length

      #KS- this time turn off ATT_CONFIRMED_PLAN_REMINDER_OPTION but leave REMIND_BY_EMAIL on
      @emails.clear
      @user.planner.mark_plan_notified(@plan, nil)
      @user.set_att(UserAttribute::ATT_CONFIRMED_PLAN_REMINDER_OPTION, UserAttribute::CONFIRMED_PLAN_REMINDER_NEVER)
      User.send_reminders(sqlize_date(Time.now))

      #KS- make sure there are no reminders since we turned off confirmed plan notifications
      assert_equal 0, @emails.find_all{|email| email.to[0] == @user.email}.length

      #KS- run it one last time with REMIND_BY_EMAIL on -- this time it should not send one because
      #that planners_plans entry should already have been marked by the last runthrough
      @emails.clear
      @user.set_att(UserAttribute::ATT_REMIND_BY_EMAIL, UserAttribute::TRUE_USER_ATT_VALUE)
      User.send_reminders(sqlize_date(Time.now))
      assert_equal 0, @emails.find_all{|email| email.to[0] == @user.email}.length
    end
  end

  #KS- commented out because the last i recall, we don't yet have a clear idea of what this
  #is supposed to do
#  def test_remind_doesnt_remind_fuzzy
#    reminder_setup
#
#    #KS- make sure there are no emails for this user
#    assert_equal 0, @emails.find_all{|email| email.to[0] == @user.email}.length
#
#    #KS- create a fuzzy plan that we shouldn't be reminded of
#    post_to_controller(PlansController.new, :create, { 'plan' => {'name' => 'a plan in the far future'},
#                                                       'dateperiod' => '7',
#                                                       'timeperiod' => '3',
#                                                       'date_month' => '',
#                                                       'date_day' => '',
#                                                       'date_year' => @year,
#                                                       'place_id' => '1',
#                                                       'place_origin' => '0'
#                                                      })
#
#    #KS- fast forward to the faaaarrrr fuuuttuuurreee
#    far_future = @date_one_week_from_now.getgm + 10.years
#    Time.set_now_gmt(far_future.year, far_future.month, far_future.day, far_future.hour) do
#      #KS- run what the reminder agent runs
#      User.send_reminders(sqlize_date(Time.now))
#
#      #KS- grab emails to the user we give a crap about
#      emails_we_care_about = @emails.find_all{|email| email.to[0] == @user.email}
#
#      #KS- make sure there is one and only one (for the original plan from setup)
#      assert_equal 1, emails_we_care_about.length
#    end
#  end

  def test_disable_all_notifications
    #MGS- test the disable all notifications link from a notification email
    # test the autologin and that the form saves the right data, etc

    #MGS- Start by making a plan, to create emails that contain URLs we can
    # use to get to plans while NOT logged in.
    login users(:bob)

    #MGS- Create a plan with good invitees: existing user, new email, exisiting user by email, some garbage space, duplicate existing user
    post_to_controller(PlansController.new, 'create', { "plan_who" => "somenewemailaddress@somedomain.com" })

    #MGS- This should send an email to somenewemailaddress for the plan
    assert_equal 1, @emails.size
    mail = @emails[0]
    assert_equal "somenewemailaddress@somedomain.com", mail.to_addrs[0].to_s
    #MGS- checking the From address
    assert_equal "#{users(:bob).full_name} #{UserNotify::EMAIL_FROM_SUFFIX}", mail.from_addrs[0].name

    #MGS- From the same URL, get the querystring arguments, like:
    # http://localhost:3000/users/disable_all_notifications?user_id=29&ci0=disable_all_notifications&cn=1&ckey=3b15a3e256963fb26e7ca23e2c3941fd39c7f629
    body = mail.plaintext_body
    m = body.match(/\/disable_all_notifications\?.*/)
    #MGS- split on the ? to get the querystring
    qs = m[0].split('?')[1]

    #MGS- Break the QS into the parts we'll pass into get methods
    map = qs.querystring_to_map

    #MGS- logout as bob
    logout
    #MGS- We should be able to see this plan using the QS
    # info, regardless of whether we're logged in
    get :disable_all_notifications, map
    assert_success
    assert :tag => 'div', :content => /Are you sure you want to stop receiving emails from Skobee\?/
    user = assigns(:user)
    #MGS- the user should have notifications turned on by default
    assert_equal 1, user.get_att_value(UserAttribute::ATT_REMIND_BY_EMAIL)

    #MGS- repost the form, storing the disable
    map["disable"] = "on"
    post :disable_all_notifications, map
    assert_success
    assert_no_tag :tag => 'div', :content => /Are you sure you want to stop receiving emails from Skobee\?/
    assert_tag :tag => 'p', :content => /You will no longer receive emails from Skobee\./
    user = assigns(:user)
    #MGS- now the user should have notifications turned off
    assert_equal 0, user.get_att_value(UserAttribute::ATT_REMIND_BY_EMAIL)
  end

  def test_resend_confirm
    #MES- Trying to resend confirmation for a nonexistent user should generate an error flash
    get :resend_confirm, :id => 123456
    assert_redirect
    assert_equal "The user you wish to confirm could not be found.  Please try again.", flash[:error]

    #MES- Likewise, trying to resend for a confirmed user should generate an error flash
    usr = users(:bob)
    get :resend_confirm, :id => usr.id
    assert_redirect
    assert_equal "User '#{usr.login}' has already been confirmed.  Please log in.", flash[:error]

    #MES- Sending a confirmation email for an unconfirmed user should, well, send an email!
    assert_equal 0, @emails.length
    usr = users(:unconfirmed_user)
    get :resend_confirm, :id => usr.id
    assert_redirect
    assert_equal 1, @emails.length
    assert_equal "New Account Confirmation", @emails[0].subject
  end

  def test_invite_new_user
    #MGS- test invites to a new email address

    #MGS- existingbob is a gen 2 user and wasn't able to access the invite new user page
    # at one point, but should be able to get to it now.
    login users(:existingbob)
    get :invite_new_user
    assert_success

    #MGS- now login as bob who can invite people
    login users(:bob)
    get :invite_new_user
    assert_success
    assert_valid_markup

    #MGS- test bogus email
    post :invite_new_user, :invite_to => "fhfhzzdfhdf", :invite_subject => 'garbled', :invite_body => 'barbled'
    assert_success
    assert_tag :tag => 'div', :attributes => { :id => "flash-error" }, :content => /One or more of the email addresses entered are invalid./
    #MES- Check that the stuff we posted is displayed again, for us to correct.
    assert_tag :tag => 'textarea', :attributes => { :id => 'invite_to' }, :content => 'fhfhzzdfhdf'
    assert_tag :tag => 'input', :attributes => { :id => 'invite_subject', :value => 'garbled', :type => 'hidden'}
    assert_tag :tag => 'textarea', :attributes => { :id => 'invite_body' }, :content => 'barbled'
    #MGS- test bogus email
    post :invite_new_user, :invite_to => ""
    assert_success
    assert_tag :tag => 'div', :attributes => { :id => "flash-error" }, :content => /You must enter an email address./
    #MGS- test bogus email
    post :invite_new_user, :invite_to => "fhfhzzdfhdf@"
    assert_success
    assert_tag :tag => 'div', :attributes => { :id => "flash-error" }, :content => /One or more of the email addresses entered are invalid./

    #MGS- test duplicate email
    assert_equal 0, @emails.length
    flash[:notice]=nil
    post :invite_new_user, :invite_to => users(:user_with_friends).email,
                           :invite_body => "hey- thought you might want to check out skobee",
                           :invite_subject => "#{users(:bob).full_name} wants you to join Skobee!"
    assert flash[:notice].match("#{users(:user_with_friends).email} already exists in the system as")
    assert_redirect
    assert_equal 0, @emails.length
    assert_nil assigns(:usr)

    #MGS- test valid email
    assert_equal 0, @emails.length
    #MGS- clear the flash
    flash[:notice]=nil
    post :invite_new_user, :invite_to => "scrubbyrise@scrubbyrise.com",
                           :invite_body => "hey- thought you might want to check out skobee",
                           :invite_subject => "#{users(:bob).full_name} wants you to join Skobee!"
    assert flash[:notice].match("Invitation sent to scrubbyrise@scrubbyrise.com")
    assert !flash[:notice].match(/Contact status successfully updated./)
    assert_equal 1, @emails.length
    assert_equal "#{users(:bob).full_name} wants you to join Skobee!", @emails[0].subject
    assert_equal "scrubbyrise@scrubbyrise.com", assigns(:usr).email
    assert @emails[0].body.match(/hey- thought you might want to check out skobee/)
    assert @emails[0].body.match(/Hey there/)
    assert @emails[0].body.match(/We should hang out soon/)

    #MGS- test valid email inviting someone as a friend
    assert_equal 1, @emails.length
    #MGS- clear the flash
    flash[:notice]=nil
    post :invite_new_user, :invite_to => "anotherscrubbyrise@scrubbyrise.com",
                           :invite_body => "hey- thought you might want to check out skobee",
                           :friend_status => User::FRIEND_STATUS_FRIEND,
                           :invite_subject => "#{users(:bob).full_name} wants you to join Skobee!"
    assert_redirect
    assert flash[:notice].match("Invitation sent to anotherscrubbyrise@scrubbyrise.com")
    assert flash[:notice].match(/Contact status successfully updated./)
    assert_equal 2, @emails.length
    assert_equal "#{users(:bob).full_name} wants you to join Skobee!", @emails[1].subject
    assert_equal "anotherscrubbyrise@scrubbyrise.com", assigns(:usr).email
    bob = User.find(users(:bob).id)
    assert bob.friends.include?(assigns(:usr))
    assert !bob.friend_contacts.include?(assigns(:usr))
    assert @emails[1].body.match(/hey- thought you might want to check out skobee/)

    #MGS- test valid email inviting someone as a contact
    assert_equal 2, @emails.length
    #MGS- clear the flash
    flash[:notice]=nil
    post :invite_new_user, :invite_to => "reallyscrubbyrise@scrubbyrise.com",
                           :invite_body => "hey- thought you might want to check out skobee",
                           :friend_status => User::FRIEND_STATUS_CONTACT,
                           :invite_subject => "#{users(:bob).full_name} wants you to join Skobee!"
    assert_redirect
    assert flash[:notice].match("Invitation sent to reallyscrubbyrise@scrubbyrise.com")
    assert flash[:notice].match(/Contact status successfully updated./)
    assert_equal 3, @emails.length
    assert_equal "#{users(:bob).full_name} wants you to join Skobee!", @emails[2].subject
    assert_equal "reallyscrubbyrise@scrubbyrise.com", assigns(:usr).email
    bob = User.find(users(:bob).id)
    assert !bob.friends.include?(assigns(:usr))
    assert bob.friend_contacts.include?(assigns(:usr))
    assert @emails[2].body.match(/hey- thought you might want to check out skobee/)
    #MGS- assert that the new user has a contact of the person who invited them
    assert assigns(:usr).friend_contacts.include?(bob)


    #MGS- invite an existing user
    #MGS- clear the flash
    flash[:notice]=nil
    post :invite_new_user, :invite_to => "reallyscrubbyrise@scrubbyrise.com"
    assert_redirect
    assert !flash[:notice].match(/Contact status sucessfully updated./)
    assert flash[:notice].match(/reallyscrubbyrise@scrubbyrise.com already exists in the system as/)

    #MGS- test four emails one of which already exists and three new emails; the user
    # that already exists already has a friend status set, so that should not change
    # the new users created should have new friend stati set.
    @emails.clear
    #MGS- clear the flash
    flash[:notice]=nil
    post :invite_new_user, :invite_to => "reallyscrubbyrise@scrubbyrise.com, b@b.com; c@c.com; d@d.com", :friend_status => User::FRIEND_STATUS_FRIEND
    assert_redirect
    assert flash[:notice].match(/Invitations sent to the following emails: b@b.com, c@c.com, d@d.com./)
    assert flash[:notice].match(/reallyscrubbyrise@scrubbyrise.com already exists in the system as/)
    assert flash[:notice].match(/Contact status successfully updated./)
    #MGS- make sure contact status was set
    bob = User.find(users(:bob).id)
    #MGS- since reallyscrubbyrise@scrubbyrise.com already existed in the system and was a contact,
    # shouldn't be upgraded to friend....however the other users should be
    assert !bob.friends.include?(User.find_by_email("reallyscrubbyrise@scrubbyrise.com"))
    assert bob.friend_contacts.include?(User.find_by_email("reallyscrubbyrise@scrubbyrise.com"))
    assert bob.friends.include?(User.find_by_email("b@b.com"))
    assert !bob.friend_contacts.include?(User.find_by_email("b@b.com"))
    assert bob.friends.include?(User.find_by_email("c@c.com"))
    assert !bob.friend_contacts.include?(User.find_by_email("c@c.com"))
    assert bob.friends.include?(User.find_by_email("d@d.com"))
    assert !bob.friend_contacts.include?(User.find_by_email("d@d.com"))
    assert_equal 3, @emails.length

    #MGS- test two users with no friend status
    @emails.clear
    #MGS- clear the flash
    flash[:notice]=nil
    post :invite_new_user, :invite_to => "test128@test.com, test256@test.com", :friend_status => User::FRIEND_STATUS_NONE
    assert_redirect
    assert flash[:notice].match(/Invitations sent to the following emails: test128@test.com, test256@test.com./)
    assert !flash[:notice].match(/Contact status successfully updated./)
    #MGS- make sure contact status was set
    bob = User.find(users(:bob).id)
    #MGS- since reallyscrubbyrise@scrubbyrise.com already existed in the system and was a contact,
    # shouldn't be upgraded to friend....however the other users should be
    assert !bob.friends.include?(User.find_by_email("test128@test.com"))
    assert !bob.friend_contacts.include?(User.find_by_email("test128@test.com"))
    assert !bob.friends.include?(User.find_by_email("test256@test.com"))
    assert !bob.friend_contacts.include?(User.find_by_email("test256@test.com"))
    assert_equal 2, @emails.length
  end

end
