require File.dirname(__FILE__) + '/../test_helper'


#########################################################################################
#MES- Simple tests that only rely on the users and emails tables
#########################################################################################
class UserTest_Simple < Test::Unit::TestCase

  def setup
    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  fixtures :users, :emails

  def test_ok_to_show_att_and_has_about_me_info
    bob = users(:bob)
    existingbob = users(:existingbob)

    #KS- set everything to public access
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_REAL_NAME_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_EMAIL_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PUBLIC, UserAttribute::ATT_GENDER_SECURITY_GROUP)
    existingbob.save!

    #KS- bob should be able to see existingbob's stuff
    assert existingbob.has_about_me_info?(bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_REAL_NAME_SECURITY_GROUP, bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_GENDER_SECURITY_GROUP, bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP, bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP, bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_EMAIL_SECURITY_GROUP, bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP, bob)

    #KS- change everything to private as possible (note that real name can only be set to all skobee) and delete the real name
    existingbob.real_name = ''
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE, UserAttribute::ATT_REAL_NAME_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_EMAIL_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_GENDER_SECURITY_GROUP)
    existingbob.save!

    #KS- bob should not be able to see any of existingbob's stuff
    assert !existingbob.has_about_me_info?(bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_REAL_NAME_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_GENDER_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_EMAIL_SECURITY_GROUP, bob)

    #KS- add back in a real name, bob should be able to see it
    existingbob.real_name = 'blahblah'
    existingbob.save!
    assert existingbob.has_about_me_info?(bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_REAL_NAME_SECURITY_GROUP, bob)

    #KS- existingbob should be able to see existingbob's own stuff
    assert existingbob.has_about_me_info?(existingbob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_REAL_NAME_SECURITY_GROUP, existingbob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP, existingbob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_GENDER_SECURITY_GROUP, existingbob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP, existingbob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP, existingbob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_EMAIL_SECURITY_GROUP, existingbob)

    #KS- make existingbob mark bob as a friend
    existingbob.add_or_update_contact(bob, { :friend_status => User::FRIEND_STATUS_FRIEND })
    existingbob.save!

    #KS- bob still shouldn't be able to see anything but real name
    assert existingbob.has_about_me_info?(bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_REAL_NAME_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_GENDER_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_EMAIL_SECURITY_GROUP, bob)

    #KS- remove the real name, shouldn't be able to see it anymore and there should be no about me info
    existingbob.real_name = ''
    assert !existingbob.has_about_me_info?(bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_REAL_NAME_SECURITY_GROUP, bob)

    #KS- put back a real name
    existingbob.real_name = 'blahblah'

    #KS- change existingbob's privacy settings to friends only
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE, UserAttribute::ATT_REAL_NAME_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_FRIENDS, UserAttribute::ATT_EMAIL_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_FRIENDS, UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_FRIENDS, UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_FRIENDS, UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP)
    existingbob.set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_FRIENDS, UserAttribute::ATT_GENDER_SECURITY_GROUP)
    existingbob.save!

    #KS- bob should be able to see everything again now
    assert existingbob.has_about_me_info?(bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_REAL_NAME_SECURITY_GROUP, bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP, bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_GENDER_SECURITY_GROUP, bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP, bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP, bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_EMAIL_SECURITY_GROUP, bob)

    #KS- remove bob as a friend
    existingbob.add_or_update_contact(bob, { :friend_status => User::FRIEND_STATUS_NONE })
    existingbob.save!

    #KS- bob shouldn't be able to see anything yet again (except for real name)
    assert existingbob.has_about_me_info?(bob)
    assert existingbob.ok_to_show_att?(UserAttribute::ATT_REAL_NAME_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_GENDER_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP, bob)
    assert !existingbob.ok_to_show_att?(UserAttribute::ATT_EMAIL_SECURITY_GROUP, bob)
  end

  def test_email_formatted_for_display_helper
    assert_equal 'kavin [at] skobee [dot] com', User.email_formatted_for_display_helper('kavin@skobee.com')
    assert_equal 'kavin [dot] stewart [at] gmail [dot] com', User.email_formatted_for_display_helper('kavin.stewart@gmail.com')
  end

  def test_find_by_primary_email
    assert_equal users(:bob), User.find_by_primary_email_address('bob@test.com')
    assert_nil User.find_by_primary_email_address('blah@skobee.com')
  end

  #KS- test all assumptions about destroy here (it should blow away any accompanying data in
  #all the tables in cascading fashion)
  def test_destroy
    #TODO: do this
    #assert false
  end

  def test_auth
    usr = User.authenticate("bob", "atest")
    assert_equal  users(:bob), usr
    assert_equal 1, usr.num_auths
    usr = User.authenticate("bob", "atest")
    assert_equal 2, usr.num_auths
    assert_nil User.authenticate("nonbob", "atest")
  end

  def test_get_user_type
    assert_equal User::USER_TYPE_REGISTERED, users(:longbob).get_user_type
    assert_equal User::USER_TYPE_UNREGISTERED, users(:unregistered_user).get_user_type
  end

  def test_disallowed_passwords

    u = User.new
    u.login = "nonbob"
    u.time_zone = 'US/Pacific'
    u.zipcode = '94105'

    u.change_password("tiny")
    assert !u.save
    assert u.errors.invalid?('password')

    u.change_password("hugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehuge")
    assert !u.save
    assert u.errors.invalid?('password')

    u.change_password("")
    assert !u.save
    assert u.errors.invalid?('password')

    u.change_password("bobs_secure_password")
    assert u.save
    assert u.errors.empty?

  end

  def test_bad_logins

    u = User.new
    u.time_zone = 'US/Pacific'
    u.change_password("bobs_secure_password")
    u.zipcode = '94105'

    u.login = "x"
    assert !u.save
    assert u.errors.invalid?('login')

    u.login = "hugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhug"
    assert !u.save
    assert u.errors.invalid?('login')

    u.login = ""
    assert !u.save
    assert u.errors.invalid?('login')

    u.login = "okbob"
    u.save
    assert u.errors.empty?

  end

  def test_collision
    u = User.new
    u.login = "existingbob"
    u.change_password("bobs_secure_password")
    assert !u.save
  end


  def test_create
    u = User.new
    u.login = "nonexistingbob"
    u.change_password("bobs_secure_password")
    u.time_zone = 'US/Pacific'
    u.zipcode = '94105'
    assert u.save
  end

  def test_fullname
    #MES- Test the user.full_name and user.full_name_and_login functions
    u = users(:bob)
    #MES- Bob has a 'real name'
    assert_equal "bob roberts_'.-_'.\"", u.full_name
    assert_equal "bob roberts_'.-_'.\" (bob)", u.full_name_and_login
    #MES- user_with_friends does not have a real name
    u = users(:user_with_friends)
    assert_equal 'user_with_friends', u.full_name
    assert_equal 'user_with_friends', u.full_name_and_login
  end

  def test_create_from_email
    #MGS- create a new user from an email address
    seed_user = users(:existingbob)
    u = User.create_user_from_email_address("random?email@randomemail.com", seed_user)
    assert_equal "random_email", u.login
    assert_equal "random?email@randomemail.com", u.email
    assert_equal seed_user.time_zone, u.time_zone
    assert_equal seed_user.lat_max, u.lat_max
    assert_equal seed_user.lat_min, u.lat_min
    assert_equal seed_user.long_max, u.long_max
    assert_equal seed_user.long_min, u.long_min
    assert_equal 3, u.generation_num
    assert_equal seed_user.id, u.invited_by
    #MGS-  make sure new user is verified
    assert u.verified == 1
    #MGS- test that the user got saved
    assert_equal User.find_by_email('random?email@randomemail.com'), u

    #MES- Test what happens when there are duplicates
    u = User.create_user_from_email_address("random.email@randomemail.aa", seed_user)
    assert_equal "random_email_1", u.login
    assert_equal "random.email@randomemail.aa", u.email

    u = User.create_user_from_email_address("random.email@randomemail.ab", seed_user)
    assert_equal "random_email_2", u.login
    assert_equal "random.email@randomemail.ab", u.email

    u = User.create_user_from_email_address("random.email@randomemail.ac", seed_user)
    assert_equal "random_email_3", u.login
    assert_equal "random.email@randomemail.ac", u.email

    u = User.create_user_from_email_address("random.email@randomemail.ad", seed_user)
    assert_equal "random_email_4", u.login
    assert_equal "random.email@randomemail.ad", u.email

    u = User.create_user_from_email_address("random.email@randomemail.ae", seed_user)
    assert_equal "random_email_5", u.login
    assert_equal "random.email@randomemail.ae", u.email

    u = User.create_user_from_email_address("random.email@randomemail.af", seed_user)
    assert_equal "random_email_6", u.login
    assert_equal "random.email@randomemail.af", u.email

    u = User.create_user_from_email_address("random.email@randomemail.ag", seed_user)
    assert_equal "random_email_7", u.login
    assert_equal "random.email@randomemail.ag", u.email

    u = User.create_user_from_email_address("random.email@randomemail.ah", seed_user)
    assert_equal "random_email_8", u.login
    assert_equal "random.email@randomemail.ah", u.email

    u = User.create_user_from_email_address("random.email@randomemail.ai", seed_user)
    assert_equal "random_email_9", u.login
    assert_equal "random.email@randomemail.ai", u.email

    u = User.create_user_from_email_address("random.email@randomemail.aj", seed_user)
    assert_equal "random_email_10", u.login
    assert_equal "random.email@randomemail.aj", u.email

    #MES- The 11th repeat should generate a random number
    u = User.create_user_from_email_address("random.email@randomemail.ak", seed_user)
    assert !u.login.match(/^random_email_[0-9]*$/).nil?
    assert_equal "random.email@randomemail.ak", u.email

    #MES- Use Mark's bad email (from ticket 939)
    u = User.create_user_from_email_address("dgsdgdg&_)(*&(@fdsf.com", seed_user)
    assert_equal "dgsdgdg_______", u.login
    assert_equal "dgsdgdg&_)(*&(@fdsf.com", u.email
  end


  def test_create_from_email_generations
    original_value = MAX_USER_GENERATION
    begin
      Object.const_set('MAX_USER_GENERATION', 5)
      #MGS- create a new user from an email address
      #MES- Existingbob has a generation of 2
      seed_user = users(:existingbob)
      u = User.create_user_from_email_address("random.email@randomemail.com", seed_user)
      assert_equal 3, u.generation_num
      u2 = User.create_user_from_email_address("random.email2@randomemail.com", u)
      assert_equal 4, u2.generation_num
      u3 = User.create_user_from_email_address("random.email3@randomemail.com", u2)
      assert_equal 5, u3.generation_num
      #MES- Since u3 has a generation of 5, it should not be able to create new users
      u4 = User.create_user_from_email_address("random.email4@randomemail.com", u3)
      assert_nil u4

      #MES- A negative value for MAX_USER_GENERATION should not impose a limit
      Object.const_set('MAX_USER_GENERATION', -23)
      u4 = User.create_user_from_email_address("random.email4@randomemail.com", u3)
      assert_equal 6, u4.generation_num
    ensure
      Object.const_set('MAX_USER_GENERATION', original_value)
    end
  end

  def test_security_token
    #MES- Test security tokens

    #MES- We should not be able to authenticate by token for a new user (since the token
    #  isn't set)
    assert_nil User.authenticate_by_token(users(:security_token_user).id, users(:security_token_user).security_token), 'Able to authenticate with an unset token'
    assert_nil User.authenticate_by_token(users(:security_token_user).id, nil), 'Able to authenticate with an nil token'
    assert_nil User.authenticate_by_token(users(:security_token_user).id, ''), 'Able to authenticate with zero length token'

    #MES- We should be able to set the token
    token = users(:security_token_user).generate_security_token
    assert_not_nil token, 'New security token is nil'

    #MES- We should be able to authenticate with that token
    u = User.authenticate_by_token(users(:security_token_user).id, token)
    assert_not_nil u, 'Authentication by token failed'

    #MES- If the token is expired, we shouldn't be able to use it
    u.destroy_security_token
    u2 = User.authenticate_by_token(users(:security_token_user).id, token)
    assert_nil u2, 'Token did not expire when it should have'
  end

  def test_find_by_string
    #MGS- various tests to see if user lookup by email/login works
    assert_equal User.find_by_string("longbob@test.com"), users(:longbob)
    assert_equal User.find_by_string("longbob"), users(:longbob)
    assert_equal User.find_by_string("bob"), users(:bob)
    assert_not_equal User.find_by_string("longbob@test.com"), users(:bob)
    assert_nil User.find_by_string("this shouldn't match anything")
    assert_nil User.find_by_string("")
    assert_kind_of User, User.find_by_string("existingbob")
  end

  def test_cannot_auth_without_confirmed_email
    #MES- unconfirmed_user should not be able to authenticate, since he doesn't
    # have a confirmed email
    user_sought = users(:unconfirmed_user)
    usr = User.authenticate(user_sought.login, 'atest')
    assert_nil usr
    #MES- If we confirm the email, he should be able to log in
    email = user_sought.emails[0]
    email.confirmed = Email::CONFIRMED
    email.save

    usr = User.find_by_string(user_sought.login)
    assert_equal 1, usr.email_object.confirmed

    usr = User.authenticate(user_sought.login, 'atest')
    assert_not_nil usr
  end

  def test_create_master_user
    usr = User.create_master_user
    assert_equal User::DEFAULT_LAT, usr.lat
    assert_equal User::DEFAULT_LONG, usr.long
    assert_not_nil usr.lat_max
    assert_not_nil usr.lat_min
    assert_not_nil usr.long_max
    assert_not_nil usr.long_min
    assert_equal User::DEFAULT_TIME_ZONE_OBJ, usr.tz
  end

  def test_create_users_from_file
    assert_nil User.find_by_email('random_email_address@goober.com')
    assert_nil User.find_by_email('another_email_address@booger.com')
    assert_nil User.find_by_email('s@sc.com')
    assert_nil User.find_by_email('s@s.uk')
    assert_nil User.find_by_email('s+1@sc.uk')
    assert_nil User.find_by_email('s+1@s.uk')
    assert_not_nil User.find_by_email('bob@test.com')
    User.create_users_from_file(File.dirname(__FILE__) + '/../data/email_addresses.txt')
    assert_not_nil User.find_by_email('random_email_address@goober.com')
    assert_not_nil User.find_by_email('another_email_address@booger.com')
    assert_not_nil User.find_by_email('s@sc.com')
    assert_not_nil User.find_by_email('s@s.uk')
    assert_not_nil User.find_by_email('s+1@sc.uk')
    assert_not_nil User.find_by_email('s+1@s.uk')
  end

  def test_create_and_email_users_from_file
    assert_equal 0, @emails.length
    assert_nil User.find_by_email('random_email_address@goober.com')
    assert_nil User.find_by_email('another_email_address@booger.com')
    assert_nil User.find_by_email('s@sc.com')
    assert_nil User.find_by_email('s@s.uk')
    assert_nil User.find_by_email('s+1@sc.uk')
    assert_nil User.find_by_email('s+1@s.uk')
    assert_not_nil User.find_by_email('bob@test.com')

    User.create_and_email_users_from_file(File.dirname(__FILE__) + '/../data/email_addresses.txt')

    random_user = User.find_by_email('random_email_address@goober.com')
    assert_not_nil random_user
    assert_not_nil User.find_by_email('another_email_address@booger.com')
    assert_not_nil User.find_by_email('s@sc.com')
    assert_not_nil User.find_by_email('s@s.uk')
    assert_not_nil User.find_by_email('s+1@sc.uk')
    assert_not_nil User.find_by_email('s+1@s.uk')
    assert_equal 6, @emails.length
    email = @emails[0]
    assert_equal 'random_email_address@goober.com', email.to[0]
    #MES- Check that the URL is in the email
    assert_not_nil email.plaintext_body.match(/users\/register\/#{random_user.id}/)
    #MES- NOTE: The functionality of the register URL is tested in UsersControllerTest.test_register

  end

  def test_has_email
    assert users(:bob).has_email?("blah@skobee.com")
    assert users(:bob).has_email?("bob@test.com")
    assert !users(:bob).has_email?("bob+1@test.com")
    assert !users(:bob).has_email?("bob@test.com.com")
    assert !users(:bob).has_email?("longbob@test.com")
  end

end

#########################################################################################
#MES- Zip code related tests
#########################################################################################
class UserTest_Zip < Test::Unit::TestCase

  fixtures :users, :zipcodes, :offsets_timezones

  def test_get_timezone_from_zip
    assert_equal 'US/Pacific', User.get_timezone_from_zip('94103')
    assert_equal 'US/Eastern', User.get_timezone_from_zip('10002')
  end

  def test_passwordchange
    users(:longbob).change_password("nonbobpasswd")
    users(:longbob).save
    assert_equal users(:longbob), User.authenticate("longbob", "nonbobpasswd")
    assert_nil User.authenticate("longbob", "alongtest")
    users(:longbob).change_password("alongtest")
    users(:longbob).save
    assert_equal users(:longbob), User.authenticate("longbob", "alongtest")
  end
end



#########################################################################################
#MES- Tests of user atts
#########################################################################################

class UserTest_Atts < Test::Unit::TestCase

  fixtures :users, :user_atts

  def test_set_att_cant_duplicate_values
    user = users(:bob)

    #KS- set a value for an arbitrary att
    user.set_att(UserAttribute::ATT_REMIND_BY_EMAIL, true)

    #KS- make sure there is only one entry for the att 1 with value 1
    atts = UserAttribute.find(:all, :conditions =>
      [ "att_id = :att_id AND user_id = :user_id",
        { :att_id => UserAttribute::ATT_REMIND_BY_EMAIL, :user_id => user.id } ])
    assert_equal 1, atts.length

    #KS- set the same att again to the same value
    user.set_att(UserAttribute::ATT_REMIND_BY_EMAIL, true)

    #KS- make sure there is only one entry for the att 1 with value 1
    atts = UserAttribute.find(:all, :conditions =>
      [ "att_id = :att_id AND user_id = :user_id",
        { :att_id => UserAttribute::ATT_REMIND_BY_EMAIL, :user_id => user.id } ])
    assert_equal 1, atts.length
  end

  def test_age_helper
    assert_equal 26, User.age_helper(1979, 6, 20, 2006, 2, 5)
    assert_equal 27, User.age_helper(1979, 6, 20, 2006, 6, 20)
    assert_equal 27, User.age_helper(1979, 6, 20, 2006, 7, 19)
    assert_equal 26, User.age_helper(1979, 6, 20, 2006, 6, 19)
    assert_nil User.age_helper(nil, 6, 20, 2006, 6, 19)
  end

  def test_delete_att
    user = users(:longbob)
    user.set_att(UserAttribute::ATT_BIRTH_YEAR, "1979")

    user = User.find(user.id)
    assert_equal "1979", user.get_att_value(UserAttribute::ATT_BIRTH_YEAR)

    num_rows_destroyed = user.delete_att(UserAttribute::ATT_BIRTH_YEAR)

    assert_equal 1, num_rows_destroyed

    user = User.find(user.id)
    assert_nil user.get_att_value(UserAttribute::ATT_BIRTH_YEAR)
  end

  def test_attributes
    usr = users(:bob)
    #MES- We should get nil if we look for a random attribute
    assert_nil usr.get_att_value(-666), 'User attribute that should not be found IS found'

    #MES- Set the attribute, and check that it's there
    usr.set_att(-666, 'value 1')
    assert_equal 'value 1', usr.get_att_value(-666), 'User attribute value was not saved correctly'

    #MES- Check that it's in the DB as well
    usr = User.find(users(:bob).id)
    assert_equal 'value 1', usr.get_att_value(-666), 'User attribute value was not saved to DB correctly'

    #MES- We should be able to set it to a different value
    usr.set_att(-666, 'value 2')
    assert_equal 'value 2', usr.get_att_value(-666), 'Altered user attribute value was not saved correctly'
    usr = User.find(users(:bob).id)
    assert_equal 'value 2', usr.get_att_value(-666), 'Altered user attribute value was not saved to DB correctly'
  end
end


#########################################################################################
#MES- Tests of user contacts
#########################################################################################

class UserTest_Contacts < Test::Unit::TestCase

  fixtures :users, :user_contacts, :user_atts, :zipcodes

  def test_relationship_exists
    user14 = User.find(14)
    assert user14.relationship_exists(15)

    user7 = User.find(7)
    assert user7.relationship_exists(8)

    user7.add_or_update_contact(User.find(8), { :friend_status => User::FRIEND_STATUS_NONE })
    assert user7.relationship_exists(8)
    assert user7.relationship_exists(9)
    assert !user7.relationship_exists(10)

    assert !users(:friend_1_of_user).relationship_exists(23)
  end

  def test_user_contacts_basic
    u = users(:bob)
    assert u.contacts.empty?, "A user that should have no contacts has a non-empty contacts list"

    #MES- Add to collection
    u.contacts << users(:existingbob)
    assert u.save, "Unable to save a user that has one item in contacts"

    #MES- Check we have one item
    u = User.find(u.id)
    assert_equal 1, u.contacts.length, "A user with one item in contacts has a contacts array with length != 1"

    #MES- Add the same item again- this should generate an error
    assert_raise(ActiveRecord::StatementInvalid) {
      u.contacts << users(:existingbob)
    }

    #MES- Add another item
    u = User.find(u.id)
    u.contacts << users(:longbob)

    #MES- Check that we have two items
    u = User.find(u.id)
    assert_equal 2, u.contacts.length, "A user with two items in contacts has a contacts array with length != 2"

    #MES- Can we remove an item?
    u.contacts.delete(users(:longbob))
    u = User.find(u.id)
    assert_equal 1, u.contacts.length, "A user with one item in contacts (due to delete) has a contacts array with length != 1"

    #MES- Can we remove all items?
    u.contacts.clear
    u = User.find(u.id)
    assert u.contacts.empty?, "A user whose contacts were cleared does not have an empty array of contacts"
  end

  def test_user_contacts_advanced
    u = users(:bob)
    assert u.contacts.empty?, "A user that should have no contacts has a non-empty contacts list"
    assert u.friends.empty?, "A user that should have no friends has a non-empty friends list"
    assert u.selected_clipboard_contacts.empty?, "A user that should have no selected contacts has a non-empty selected_clipboard_contacts list"
    assert u.checked_clipboard_contacts.empty?, "A user that should have no checked contacts has a non-empty checked_clipboard_contacts list"

    another = users(:existingbob)
    u.contacts.push_with_attributes another, :friend_status => User::FRIEND_STATUS_FRIEND, :clipboard_status => User::CLIPBOARD_STATUS_CHECKED
    assert_equal 1, u.contacts.length
    assert_equal 1, u.friends.length
    assert_equal 0, u.friend_contacts.length
    assert_equal 1, u.friends_and_contacts.length
    assert_equal 1, u.selected_clipboard_contacts.length
    assert_equal 1, u.checked_clipboard_contacts.length

    u.add_or_update_contact(another, { :friend_status => User::FRIEND_STATUS_NONE })
    assert_equal 1, u.contacts.length
    assert_equal 0, u.friends.length
    assert_equal 0, u.friend_contacts.length
    assert_equal 0, u.friends_and_contacts.length
    assert_equal 1, u.selected_clipboard_contacts.length
    assert_equal 1, u.checked_clipboard_contacts.length

    u.add_or_update_contact(another, { :clipboard_status => User::CLIPBOARD_STATUS_SELECTED })
    assert_equal 1, u.contacts.length
    assert_equal 0, u.friends.length
    assert_equal 0, u.friend_contacts.length
    assert_equal 0, u.friends_and_contacts.length
    assert_equal 1, u.selected_clipboard_contacts.length
    assert_equal 0, u.checked_clipboard_contacts.length

    #MGS- also test User.add_or_update_contact here
    u.add_or_update_contact(users(:x_dummy_user_1), { :friend_status => User::FRIEND_STATUS_FRIEND })
    #MGS- make sure that contacts increased, even though we just added as friend
    assert_equal 2, u.contacts.length
    assert_equal 1, u.friends.length
    assert_equal 0, u.friend_contacts.length
    assert_equal 1, u.friends_and_contacts.length
    assert_equal 1, u.selected_clipboard_contacts.length
    assert_equal 0, u.checked_clipboard_contacts.length
    assert_equal 0, u.contacts[1].clipboard_status.to_i
    assert_equal 1, u.contacts[1].friend_status.to_i

    u.add_or_update_contact(users(:x_dummy_user_2), { :clipboard_status => User::CLIPBOARD_STATUS_SELECTED })
    assert_equal 3, u.contacts.length
    assert_equal 1, u.friends.length
    assert_equal 0, u.friend_contacts.length
    assert_equal 1, u.friends_and_contacts.length
    assert_equal 2, u.selected_clipboard_contacts.length
    assert_equal 0, u.checked_clipboard_contacts.length
    assert_equal 1, u.contacts[2].clipboard_status.to_i
    assert_equal 0, u.contacts[2].friend_status.to_i

    u.add_or_update_contact(users(:x_dummy_user_3), { :friend_status => User::FRIEND_STATUS_FRIEND, :clipboard_status => User::CLIPBOARD_STATUS_SELECTED })
    assert_equal 4, u.contacts.length
    assert_equal 2, u.friends.length
    assert_equal 0, u.friend_contacts.length
    assert_equal 2, u.friends_and_contacts.length
    assert_equal 3, u.selected_clipboard_contacts.length
    assert_equal 0, u.checked_clipboard_contacts.length
    assert_equal 1, u.contacts[3].clipboard_status.to_i
    assert_equal 1, u.contacts[3].friend_status.to_i

    u.add_or_update_contact(users(:x_dummy_user_4), { :friend_status => User::FRIEND_STATUS_CONTACT })
    assert_equal 5, u.contacts.length
    assert_equal 2, u.friends.length
    assert_equal 1, u.friend_contacts.length
    assert_equal 3, u.friends_and_contacts.length
    assert_equal 3, u.selected_clipboard_contacts.length
    assert_equal 0, u.checked_clipboard_contacts.length
    assert_equal 0, u.contacts[4].clipboard_status.to_i
    assert_equal 2, u.contacts[4].friend_status.to_i
  end

  def test_find_friends_inverse
    #MGS- find the users who have selected friend_2_of_user as their friend
    inverse_friends = User.find_friends_inverse(users(:friend_2_of_user))
    assert_equal 3, inverse_friends.length, "the number of users who have selected friend_2_of_user as a friend should be 3"
    assert_equal users(:user_with_friends_and_private_cal), inverse_friends[0]
    assert_equal users(:user_with_friends_and_friends_cal), inverse_friends[1]
    assert_equal users(:user_with_friends), inverse_friends[2]
  end

  def test_find_contacts_inverse
    #MGS- find the users who have selected friend_2_of_user as their contact or friend
    inverse_contacts = User.find_contacts_inverse(users(:friend_2_of_user))
    assert_equal 4, inverse_contacts.length, "the number of users who have selected friend_2_of_user as a contact should be 4"

    assert_equal users(:existingbob), inverse_contacts[0]
    assert_equal users(:user_with_friends), inverse_contacts[1]
    assert_equal users(:user_with_friends_and_friends_cal), inverse_contacts[2]
    assert_equal users(:user_with_friends_and_private_cal), inverse_contacts[3]
  end

  def test_find_regulars
    #MES- Find invitees with a high limit
    recent_invitees = User.find_regulars(users(:user_with_friends_and_private_cal), 10)
    #MES- The array should include friend_1_of_user and friend_2_of_user, and nothing else
    assert_equal 2, recent_invitees.length, 'Recent invitees should contain 2 entries'
    assert_equal users(:friend_1_of_user), recent_invitees[0], 'friend_1_of_user should be position 0'
    assert_equal users(:friend_2_of_user), recent_invitees[1], 'friend_2_of_user should be position 1'

    #MES- Do the same thing, but retrieve only one item, and look up by ID
    recent_invitees = User.find_regulars(users(:user_with_friends_and_private_cal).id, 1)
    #MES- The array should include friend_1_of_user, and nothing else
    assert_equal 1, recent_invitees.length, 'Recent invitees should contain 1 entries'
    assert_equal users(:friend_1_of_user), recent_invitees[0], 'friend_1_of_user should be position 0'
    
    #MES- Sort by name
    usr = users(:friend_1_of_user)
    usr.real_name = "sort second" #MES- "sort second" should sort after "friend_2_of_user"
    usr.save!
    
    recent_invitees = User.find_regulars(users(:user_with_friends_and_private_cal), 10, true)
    assert_equal 2, recent_invitees.length, 'Recent invitees should contain 2 entries'
    assert_equal users(:friend_2_of_user), recent_invitees[0], 'friend_2_of_user should be position 0'
    assert_equal users(:friend_1_of_user), recent_invitees[1], 'friend_1_of_user should be position 1'
  end

end

#########################################################################################
#MES- Tests of plans and places
#########################################################################################

class UserTest_PlansAndPlaces < Test::Unit::TestCase
  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  def setup
    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  fixtures :users, :planners_plans, :places, :plans, :emails, :user_atts

  def test_user_places
    #MES- We're not going to test this extensively, since it's straight from Rails.
    # Just some simple tests to make sure we haven't destroyed this functionality.
    u = users(:bob)
    vens = u.places
    assert_equal 2, vens.length, 'Bob should own two places'

    u = users(:existingbob)
    vens = u.places
    assert_equal 0, vens.length, 'Existingbob should own zero places'
  end

  def test_find_users_and_plans_needing_reminders
    items = User.find_users_and_plans_needing_reminders

    #MES- We should get three item containing three and four plans respectively
    assert_equal 3, items.length
    assert_equal 3, items[0][1].length
    assert_equal 3, items[1][1].length

    assert_equal users(:existingbob), items[0][0]
    assert_equal plans(:first_plan), items[0][1][0]
    assert_equal plans(:plan_for_bob_place), items[0][1][1]
    assert_equal plans(:solid_plan_in_expiry_window), items[0][1][2]

    assert_equal users(:longbob), items[1][0]
    assert_equal plans(:first_plan), items[1][1][0]
    assert_equal plans(:longbob_plan), items[1][1][1]
    assert_equal plans(:solid_plan_in_expiry_window), items[1][1][2]
  end

  def test_reminder
    response = UserNotify.create_remind(users(:existingbob), Plan.find(4))

    assert_equal users(:existingbob).email, response.to[0], 'Reminder sent to wrong user'
    assert_match Regexp.new("#{plans(:first_plan).name}"), response.body, 'plan not found in body of reminder'
  end

  def test_send_reminders
    @emails.clear
    User.send_reminders

    #KS- we should have 2 plan expiry reminders (fuzzy plans about to expire) and 1 regular reminder for existingbob
    assert_equal 2, @emails.find_all{|email| email.to[0] == users(:existingbob).email && email.subject =~ /is about to expire/}.length
    assert_equal 1, @emails.find_all{|email| email.to[0] == users(:existingbob).email && email.body =~ /Don't forget the following plans/}.length

    #KS- we should have 3 plan expiry reminders (fuzzy plans about to expire) and 1 regular reminder for longbob
    assert_equal 1, @emails.find_all{|email| email.to[0] == users(:longbob).email && email.body =~ /Don't forget the following plans/}.length
    assert_equal 2, @emails.find_all{|email| email.to[0] == users(:longbob).email && email.subject =~ /is about to expire/}.length

    #KS- regular users should not get a reminder if they are not in
    assert_equal 0, @emails.find_all{|email| email.to[0] == users(:user_with_contacts).email}.length
    assert_equal 0, @emails.find_all{|email| email.to[0] == users(:user_with_friends).email}.length

    #KS- unregistered users should get a reminder if they are invited but not if they rejected
    p "#{users(:unregistered_user).email}"
    assert_equal 1, @emails.find_all{|email| email.to[0] == users(:unregistered_user).email && email.subject =~ /solid_plan_in_expiry_window/}.length
  end

  def test_update_contacts_on_accept_plan
    #MES- At the start of the test, user friend_1_of_user should not
    # consider friend_2_of_user a contact
    usr1 = users(:friend_1_of_user)
    usr2 = users(:friend_2_of_user)
    assert !usr1.contacts.include?(usr2), 'User friend_1_of_user should NOT consider user friend_2_of_user a contact at the start of the test'

    #MES- When user friend_1_of_user accepts plan user_with_friends_and_private_cal_plan,
    # that should make user friend_2_of_user a contact
    pln = plans(:user_with_friends_and_private_cal_plan)
    usr2.planner.accept_plan pln, usr2
    usr1.planner.accept_plan pln, usr1

    start_now = Time.new.utc
    assert usr1.contacts.include?(usr2), 'User friend_1_of_user should consider user friend_2_of_user a contact after accepting a plan they have in common'
    #MES- And the "contact_created_at" for the contact should be
    #  near now in GMT
    ctct = usr1.contacts.find usr2.id
    ctct_time = Time.parse(ctct.contact_created_at + ' GMT')
    assert ctct_time.to_f >= (start_now.to_f - 3)
    assert ctct_time.to_f <= (Time.new.utc.to_f + 3)
  end

  def test_find_attended_place
    users = User.find_attended_place(places(:first_place))
    #MES- There should be 5 users returned
    assert_equal 5, users.length, 'Wrong number of users returned'
    #MES- And they should be in a specific order
    assert_equal users(:user_with_contacts), users[0]
    assert_equal users(:contact_2_of_user), users[1]
    assert_equal users(:contact_1_of_user), users[2]
    assert_equal users(:user_with_friends), users[3]
    assert_equal users(:friend_1_of_user), users[4]

    #MES- Try to limit the returns
    users = User.find_attended_place(places(:first_place), 2)
    #MES- There should be 2 users returned
    assert_equal 2, users.length, 'Wrong number of users returned'
    #MES- And they should be in a specific order
    assert_equal users(:user_with_contacts), users[0]
    assert_equal users(:contact_2_of_user), users[1]

    #MES- Try passing in an ID
    users = User.find_attended_place(places(:first_place).id)
    #MES- There should be 5 users returned
    assert_equal 5, users.length, 'Wrong number of users returned'

    #MES- DEFUNCT- We no longer support status of STATUS_ALTERED, but the test is
    # still good- just substitute STATUS_ACCEPTED
    #MGS- this should also return users with a status of Plan::STATUS_ALTERED as well
    users = User.find_attended_place(places(:place_owned_by_user_with_friends_and_friends_cal))
    assert_equal 1, users.length, 'Wrong number of users returned'
    assert_equal users(:existingbob), users[0]

    #MES- When a plan is private, we should NOT find places based on the plan
    pln = plans(:plan_for_place_stats)
    pln.security_level = Plan::SECURITY_LEVEL_PRIVATE
    pln.save!
    users = User.find_attended_place(places(:first_place))
    #MES- There should be 5 users returned
    assert_equal 5, users.length, 'Wrong number of users returned'
    #MES- And they should be in a specific order
    assert_equal users(:contact_2_of_user), users[0]
    assert_equal users(:contact_1_of_user), users[1]
    assert_equal users(:user_with_friends), users[2]
    assert_equal users(:friend_1_of_user), users[3]
    assert_equal users(:existingbob), users[4]
  end
end

#########################################################################################
#MGS- Tests of plans and user_contacts
#########################################################################################

class UserTest_PlansAndContacts < Test::Unit::TestCase

  def setup
    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  fixtures :users, :planners_plans, :plans, :user_contacts

  def test_accepted_users_have_relationship
    #MGS- get the 'viewing user' all the unit tests below use this
    # user as the viewer for different plans
    friend_1_of_user = users(:friend_1_of_user)

    #MGS- test where user has marked as friend and has accepted
    # the only accepted user on this plan is user_with_friends_and_friends_cal
    # who has set friend_1_of_user as a friend
    plan = plans(:plan_just_for_user_with_friends_and_friends_cal)
    assert User.accepted_users_have_relationship?(friend_1_of_user.id, plan.id)

    #MGS- same test as above, but test passing in objects instead of id's as parameters
    plan = plans(:plan_just_for_user_with_friends_and_friends_cal)
    assert User.accepted_users_have_relationship?(friend_1_of_user, plan)

    #MGS- test where user has marked as contact and has accepted
    # user_with_friends has marked friend_1_of_user as a contact and is accepted on this plan
    plan = plans(:future_plan_2)
    assert User.accepted_users_have_relationship?(friend_1_of_user, plan.id)

    #MGS- test where someone who has set you as a friend is on a plan but has rejected it
    # user_with_friends has set friend_1_of_user as a friend, but is rejected on this plan
    plan = plans(:solid_plan_in_expiry_window)
    assert_equal false, User.accepted_users_have_relationship?(friend_1_of_user, plan.id)

    #MGS- test tenative status
    # user_with_friends has set friend_1_of_user as a friend, but is only invited on this plan
    plan = plans(:first_plan)
    assert !User.accepted_users_have_relationship?(friend_1_of_user, plan.id)
  end
end


#########################################################################################
#MES- Tests of planners
#########################################################################################

class UserTest_Planner < Test::Unit::TestCase

  fixtures :users, :planners

  def test_user_cal
    #MES- Every user should have a planner
    u = User.new
    u.login = 'newcal'
    u.time_zone = 'US/Pacific'
    u.change_password 'a_secure_password'
    u.zipcode = '94105'
    assert_not_nil u.planner, 'New user has a nil default planner'
    assert_kind_of Planner, u.planner, 'The planner of an unsaved user is NOT of type Planner'

    #MES- If we save and reopen the user, it should still have a default planner
    assert u.save
    u2 = User.find(u.id)
    assert_not_nil u2, 'Unable to reopen user with default planner'
    assert_not_nil u2.planner, 'Saved user has a nil planner'
    assert_kind_of Planner, u.planner, 'The planner of a saved user is NOT of type Planner'

    #MES- If we delete the user, the default planner for the user should also be deleted
    assert_not_nil Planner.find(u2.planner.id), 'The planner for a saved user could not be found'
    u2.destroy
    assert_raise(ActiveRecord::RecordNotFound) { Planner.find(u2.planner.id) }

  end
end


#########################################################################################
#MES- Tests of user fulltext indexing
#########################################################################################

class UserTest_Fulltext < Test::Unit::TestCase

  def setup
    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  #MES- The users_fulltext table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :users, :users_fulltext, :emails, :zipcodes, :offsets_timezones

  def test_find_by_ft
    #MES- find_by_ft is similar to find_by_string, but uses fulltext semantics
    longbob = users(:longbob)
    bob = users(:bob)
    res = User.find_by_ft("longbob", bob.id)
    assert_equal 1, res.length
    assert_equal res[0], longbob
    res = User.find_by_ft("longbob@test.com", bob.id)
    assert_equal 1, res.length
    assert_equal res[0], longbob
    res = User.find_by_ft("longbob@test.com", longbob.id)
    assert_equal 0, res.length
    res = User.find_by_ft("bob", longbob.id)
    assert_equal 1, res.length
    assert_equal res[0], bob
    res = User.find_by_ft("roberts_'.\"", longbob.id)
    assert_equal 1, res.length
    assert_equal res[0], bob
    res = User.find_by_ft("roberts_'.\" bob", longbob.id)
    assert_equal 1, res.length
    assert_equal res[0], bob
    res = User.find_by_ft("robert", longbob.id)
    assert_equal 0, res.length

    #MES- Passing in crap should have predictable results
    res = User.find_by_ft("no match", longbob.id)
    assert_equal 0, res.length
    res = User.find_by_ft("", longbob.id)
    assert_equal 0, res.length
    res = User.find_by_ft(nil, longbob.id)
    assert_equal 0, res.length

    #MES- If we make a NEW user, they should also be available
    newusr = User.new(:login => 'ft_user', :real_name => 'ft name', :time_zone => 'US/Pacific')
    newusr.zipcode = '94105'
    newusr.save!
    res = User.find_by_ft("ft_user", bob.id)
    assert_equal 1, res.length
    assert_equal res[0], newusr
    res = User.find_by_ft("ft_user", newusr.id)
    assert_equal 0, res.length
  end

  def test_users_fulltext
    #MES- Test that the triggers keep the users_fulltext table in sync with the users table
    assert_equal 0, User.perform_select_all_sql("SELECT COUNT(*) AS CT FROM users_fulltext WHERE searchable = 'test_fulltext test fulltext_\\'.\"'")[0]['CT'].to_i

    #MES- Create a user with that name, check that it gets stored
    usr = User.new(:login => 'test_fulltext', :real_name => "test fulltext_'.\"", :time_zone => 'US/Pacific')
    usr.zipcode = '94105'
    usr.save!
    assert_equal 1, User.perform_select_all_sql("SELECT COUNT(*) AS CT FROM users_fulltext WHERE searchable = 'test_fulltext test fulltext_\\'.\"'")[0]['CT'].to_i

    #MES- Changes should also be reflected
    usr.real_name = 'test fulltext again'
    usr.save!
    assert_equal 0, User.perform_select_all_sql("SELECT COUNT(*) AS CT FROM users_fulltext WHERE searchable = 'test_fulltext test fulltext_\\'.\"'")[0]['CT'].to_i
    assert_equal 1, User.perform_select_all_sql("SELECT COUNT(*) AS CT FROM users_fulltext WHERE searchable = 'test_fulltext test fulltext again'")[0]['CT'].to_i

    #MES- And deletions
    usr.destroy
    assert_equal 0, User.perform_select_all_sql("SELECT COUNT(*) AS CT FROM users_fulltext WHERE searchable = 'test_fulltext test fulltext_\\'.\"'")[0]['CT'].to_i
    assert_equal 0, User.perform_select_all_sql("SELECT COUNT(*) AS CT FROM users_fulltext WHERE searchable = 'test_fulltext test fulltext again'")[0]['CT'].to_i

    #MES- It should be possible to have no real_name
    usr = User.new(:login => 'test_fulltext', :time_zone => 'US/Pacific')
    usr.zipcode = '94105'
    usr.save!
    assert_equal 1, User.perform_select_all_sql("SELECT COUNT(*) AS CT FROM users_fulltext WHERE searchable = 'test_fulltext '")[0]['CT'].to_i

  end

end


#########################################################################################
#MES- Tests of merging users
#########################################################################################

class UserTest_Merge < Test::Unit::TestCase
  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :users, :user_atts, :user_contacts, :planners, :planners_plans, :comments, :emails, :feedbacks, :places, :plan_changes, :user_contacts, :zipcodes, :offsets_timezones

  def test_merge
    #KS- first need to set users 25 and 26's emails to confirmed
    user_25_email = User.find(25).email_object
    user_25_email.confirmed = Email::CONFIRMED
    user_25_email.save!
    user_26_email = User.find(26).email_object
    user_26_email.confirmed = Email::CONFIRMED
    user_26_email.save!

    #KS- before the first merge there should be 3 of 'existingbob2@test.com' in the db
    select_duplicate_email_sql = "SELECT * FROM emails WHERE address = 'existingbob2@test.com'"
    assert_equal 3, User.perform_select_all_sql([select_duplicate_email_sql]).length

    #KS- set the invited_by field so that each user was invited by the user numerically preceding them
    for i in 2..26
      user = User.find(i)
      user.invited_by = i - 1
      user.save!
    end

    #KS- do merges merging every single user to user 1
    User.merge(User.find(1), User.find(2))

    #KS- make sure the merge didn't delete the email that's a dupe that's owned by longbob
    assert_equal 2, User.perform_select_all_sql([select_duplicate_email_sql]).length

    #KS- merge users 3-9 to 1
    for i in 3..9
      User.merge(User.find(1), User.find(i))
      assert_equal 1, User.find(i + 1).invited_by
    end

    #KS- make sure no one still has user 9 marked as a contact
    select_user_contacts_inverse_sql = "SELECT * FROM user_contacts WHERE contact_id = 9"
    assert_equal 0, User.perform_select_all_sql([select_user_contacts_inverse_sql]).length

    #KS- merge users 10-26 to 1
    for i in 10..26
      User.merge(User.find(1), User.find(i))
      assert_equal 1, User.find(i + 1).invited_by if i < 26
    end

    #KS- make sure no data from any other user is found in any of the
    #tables that should have been merged over or deleted
    user_id_hash = {:user_id => 1}
    select_comments_sql = "SELECT * FROM comments WHERE owner_id != :user_id"
    assert_equal 0, User.perform_select_all_sql([select_comments_sql, user_id_hash]).length
    select_emails_sql = "SELECT * FROM emails WHERE user_id != :user_id"
    assert_equal 0, User.perform_select_all_sql([select_emails_sql, user_id_hash]).length
    select_feedbacks_sql = "SELECT * FROM feedbacks WHERE user_id != :user_id"
    assert_equal 0, User.perform_select_all_sql([select_feedbacks_sql, user_id_hash]).length
    select_pictures_sql = <<-END_OF_STRING
      SELECT *
      FROM
        pictures
      WHERE
        id = (SELECT image_id FROM users WHERE users.id != :user_id) OR
        id = (SELECT thumbnail_id FROM users WHERE users.id != :user_id)
    END_OF_STRING
    assert_equal 0, User.perform_select_all_sql([select_pictures_sql, user_id_hash]).length
    select_places_sql = "SELECT * FROM places WHERE user_id != :user_id"
    assert_equal 0, User.perform_select_all_sql([select_places_sql, user_id_hash]).length
    select_plan_changes_sql = "SELECT * FROM plan_changes WHERE owner_id != :user_id"
    assert_equal 0, User.perform_select_all_sql([select_plan_changes_sql, user_id_hash]).length
    select_planners_sql = "SELECT * FROM planners WHERE user_id != :user_id"
    assert_equal 0, User.perform_select_all_sql([select_planners_sql, user_id_hash]).length
    select_planners_plans_sql = "SELECT * FROM planners_plans WHERE user_id_cache != :user_id"
    assert_equal 0, User.perform_select_all_sql([select_planners_plans_sql, user_id_hash]).length
    select_user_atts_sql = "SELECT * FROM user_atts WHERE user_id != :user_id"
    assert_equal 0, User.perform_select_all_sql([select_user_atts_sql, user_id_hash]).length
    select_user_contacts_sql = "SELECT * FROM user_contacts WHERE user_id != :user_id"
    assert_equal 0, User.perform_select_all_sql([select_user_contacts_sql, user_id_hash]).length
    select_user_contacts_inverse_sql = "SELECT * FROM user_contacts WHERE contact_id != :user_id"
    assert_equal 0, User.perform_select_all_sql([select_user_contacts_inverse_sql, user_id_hash]).length
    select_users_sql = "SELECT * FROM users WHERE id != :user_id"
    assert_equal 0, User.perform_select_all_sql([select_users_sql, user_id_hash]).length

    #KS- make sure there are no duplicated emails
    select_duplicate_emails_sql = "SELECT * FROM emails AS e1, emails AS e2 WHERE e1.id != e2.id AND e1.address = e2.address"
    assert_equal 0, User.perform_select_all_sql([select_duplicate_emails_sql]).length
  end

#########################################################################################
# KS- picture related tests
#########################################################################################

  def test_make_primary
    #KS- load dummy user to add the image to
    user = users(:bob)

    #KS- create the image
    uploaded_pic = uploaded_jpeg(File.dirname(__FILE__) + '/../data/tiny_smedberg.jpg', 'tiny_smedberg.jpg')
    pic = Picture.new({'picture' => uploaded_pic, 'size_type' => Picture::SIZE_FULL})
    pic.resize_and_save!
    thumbnail = pic.create_thumbnail
    medium = pic.create_medium

    #KS- make sure trying to add image as primary raises exception if that image
    #doesn't belong to the user
    assert_raise(RuntimeError){ user.make_primary(pic) }

    #KS- add the image to the user's list of images
    user.pictures << pic
    user.pictures << thumbnail
    user.pictures << medium
    user.save!

    #KS- try making primary via the thumbnail
    set_user_primary_pics_to_nil(user)
    assert !user.primary?(thumbnail)
    assert !user.primary?(medium)
    assert !user.primary?(pic)
    user.make_primary(thumbnail)

    #KS- make sure it worked
    user = User.find(user.id)
    assert user.primary?(thumbnail)
    assert user.primary?(medium)
    assert user.primary?(pic)

    #KS- try making primary via the medium
    set_user_primary_pics_to_nil(user)
    assert !user.primary?(thumbnail)
    assert !user.primary?(medium)
    assert !user.primary?(pic)
    user.make_primary(medium)

    #KS- make sure it worked
    user = User.find(user.id)
    assert user.primary?(thumbnail)
    assert user.primary?(medium)
    assert user.primary?(pic)

    #KS- try making primary via the full size pic
    set_user_primary_pics_to_nil(user)
    assert !user.primary?(thumbnail)
    assert !user.primary?(medium)
    assert !user.primary?(pic)
    user.make_primary(pic)

    #KS- make sure it worked
    user = User.find(user.id)
    assert user.primary?(thumbnail)
    assert user.primary?(medium)
    assert user.primary?(pic)
  end

  private
  def set_user_primary_pics_to_nil(user)
    user.image = nil
    user.thumbnail = nil
    user.medium_image = nil

    user.save!

    assert_nil user.image
    assert_nil user.thumbnail
    assert_nil user.medium_image
  end
end
