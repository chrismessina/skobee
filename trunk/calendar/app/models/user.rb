require 'digest/sha1'
require 'email'

# this model expects a certain database layout and its based on the name/login pattern.
class User < ActiveRecord::Base
  #MGS- adding comments to user's profiles
  has_and_belongs_to_many :comments, :order => "created_at DESC"

  CLIPBOARD_STATUS_NONE = 0    #MES- This is a contact, but neither selected nor checked; previously CONTACT_STATUS_NONE
  CLIPBOARD_STATUS_SELECTED = 1  #MES- This is a contact in which we're particularly interested; previously CONTACT_STATUS_SELECTED
  CLIPBOARD_STATUS_CHECKED = 2  #MES- This is a contact in which we're particularly interested AND which is checked in the UI; previously CONTACT_STATUS_CHECKED
  SELECTED_CLIPBOARD_STATUSES = [CLIPBOARD_STATUS_SELECTED, CLIPBOARD_STATUS_CHECKED]

  FRIEND_STATUS_NONE = 0    #MES- This user is NOT a friend
  FRIEND_STATUS_FRIEND = 1  #MES- This user IS a friend
  FRIEND_STATUS_CONTACT = 2  #MES- This user IS a contact

  SESSION_LIFETIME_SECS = 3600

  HASH_LENGTH = 40 #MES- Length of hashes (e.g. of password hash, salt, etc.)


  USER_TYPE_NORMAL = 0
  USER_TYPE_ADMIN = 1

  DEFAULT_MAX_PROX_SEARCH_MILES = 60

  #MES- The default latitude and longitude to use when
  # location should be guessed.  This happens to be
  # the location of Skobee World Headquarters (and
  # hence the center of the world.)
  DEFAULT_LAT = 37.7879999999999936
  DEFAULT_LONG = -122.4

  #MES- The default timezone
  DEFAULT_TIME_ZONE = 'US/Pacific'
  DEFAULT_TIME_ZONE_OBJ = TZInfo::Timezone.get(DEFAULT_TIME_ZONE)

  #KS- the number of hours before the end of a fuzzy period when an expiry
  #reminder will be send to the user
  POSTPONE_EXPIRY_WINDOW = 36

  MIN_LOGIN_LENGTH = 3
  MAX_LOGIN_LENGTH = 80

  #MES- The zipcode for international users- users in this zip code are not in the US
  INTL_USER_ZIPCODE_STR = '00000'

  ALLOWED_LOGIN_CHARS = 'a-zA-Z0-9\-_+'

  has_one :planner, :dependent => true
  has_many :places, :dependent => true
  has_many :emails, :dependent => true

  #MES- We use user_atts to store semi-extensible attributes of the user, such as
  # home address or SMS number.
  has_many :user_atts, :class_name => 'UserAttribute', :dependent => true

  #KS- picture stuff
  has_and_belongs_to_many :pictures
  belongs_to :image, :class_name => 'Picture', :foreign_key => 'image_id'
  belongs_to :medium_image, :class_name => 'Picture', :foreign_key => 'medium_image_id'
  belongs_to :thumbnail, :class_name => 'Picture', :foreign_key => 'thumbnail_id'

  #MES- We protect the "user_type" attribute- users shouldn't be able to change
  # their own type (e.g. to change themselves to Admin.)  For now, there is no
  # way to change type through the API- it has to be done via SQL.  This is a
  # little inconvenient, but adds some measure of security.
  attr_protected :user_type

  #MES- We also don't want the password assigned in a "bulk" manner (by setting
  # the attributes hash), since this might let a person walking by a logged in computer
  # reset the password for a logged in user WITHOUT knowing the CURRENT password (they'd
  # have to do a custom get or post or something, but it's possible.)
  attr_protected :password
  attr_protected :salted_password
  attr_protected :salt
  attr_protected :security_token

  #MES- Contacts are the people that you're interested in- e.g. the people whose planner you want to see.
  has_and_belongs_to_many :contacts, :class_name => 'User', :join_table => 'user_contacts', :association_foreign_key => 'contact_id', :order => 'connections DESC'

  attr_accessor :new_password
  attr_accessor :remember_me
  attr_accessor :zipcode
  #MES- Normally, we want to assure that user logins are unique.
  # However, when we're registering a user, we don't want to perform this check- the
  # user may go through the signup screen, and enter the email address attached to their
  # (pre-existing) account.  In this case, we still want to validate that the data they
  # entered is good (e.g. that the password and confirm password match), but we do NOT
  # want to check that the login is unique.  This flag lets the controller tell the model not to
  # check for uniqueness.
  attr_accessor :suppress_uniqueness_validation

  composed_of :tz, :class_name => 'TZInfo::Timezone', :mapping => %w(time_zone time_zone)

  #KS- ensure email addresses are unique; currently i'm calling a custom before_update
  #because i couldn't get validates_uniqueness_of to work properly with the functional
  #tests (although it appeared to be working properly during manual testing). this
  #should probably be revisited at some point.
  #validates_uniqueness_of :email
  #KS- the different types of users
  USER_TYPE_REGISTERED = 0
  USER_TYPE_UNREGISTERED = 1

  #KS- use this method to bring the data in the database in line with the multiple pictures
  #schema after the schema changes have been applied. this method will do the following for each user:
  # - make entry in pictures_users for both image and thumbnail
  # - set height, width, and size_type for existing thumbnails and user images
  # - create medium pic for user from fullsize
  # - resize the fullsize pic to fit inside a MAX_HEIGHT X MAX_WIDTH box (maintaining the aspect ratio)
  # - set original_id for thumbnail
  def self.update_old_pics_table
    users = User.find(:all, :conditions => ["thumbnail_id IS NOT NULL AND medium_image_id IS NULL"])

    while users.length > 0
      users.each{ |user|
        user.update_users_old_pic
        putc '.'
      }

      users = User.find(:all, :conditions => ["thumbnail_id IS NOT NULL AND medium_image_id IS NULL"])
    end
  end

  #KS- the update_old_pics_table method will call this on each user
  def update_users_old_pic
    #KS- get the thumbnail and full image
    thumbnail = self.thumbnail
    full_image = self.image

    #KS- make entry in pictures_users for image and thumbnail
    self.pictures << thumbnail
    self.pictures << full_image
    self.save!

    #KS- set height, width, and size_type for thumbnail and full_image
    thumbnail.set_dimensions!
    thumbnail.size_type = Picture::SIZE_THUMBNAIL
    thumbnail.save_with_validation(false)
    full_image.set_dimensions!
    full_image.size_type = Picture::SIZE_FULL

    #KS- create a medium image and set the user's medium_image to it
    medium_image = full_image.create_medium
    medium_image.save_with_validation(false)
    self.pictures << medium_image
    self.medium_image = medium_image
    self.save!

    #KS- resize the full size pic to the new maximum dimensions
    full_image.resize_and_save!(Picture::MAX_HEIGHT, Picture::MAX_WIDTH, false)

    #KS- set the thumbnail's original
    thumbnail.original = full_image
    thumbnail.save_with_validation(false)
  end

  #KS- make this picture primary for the given user. this will take any of the images within an image set (where
  #all of them are various resizings of one another).
  def make_primary(picture)
    #KS- find the original
    original = picture.original_or_this

    #KS- get the thumbnail and medium
    medium_image = self.pictures.detect{ |pic| pic.original == original && pic.size_type == Picture::SIZE_MEDIUM}
    thumbnail = self.pictures.detect{ |pic| pic.original == original && pic.size_type == Picture::SIZE_THUMBNAIL}

    #KS- if either array has a length of anything but one, we've got a problem
    if medium_image.nil?
      raise "Error: there should be one and only one medium picture for picture #{original.id} owned by user #{self.id}"
    end
    if thumbnail.nil?
      raise "Error: there should be one and only one thumbnail picture for picture #{original.id} owned by user #{self.id}"
    end

    self.image = original
    self.medium_image = medium_image
    self.thumbnail = thumbnail
    self.save!
  end

  #KS- is this picture a primary fullsize image or thumbnail for the given user?
  def primary?(picture)
    return self.thumbnail == picture || self.medium_image == picture || self.image == picture
  end

  #KS- use this to figure out if it's ok to display user_atts under a particular
  #security group to the current user
  #MES- TODO: Shouldn't this function be in UserAttribute?
  def ok_to_show_att?(security_group, viewing_user)
    #KS- if there's nothing to show, it's not ok to show it (note: no need
    #to check email because we assume that a user MUST have an email)
    case security_group
      when UserAttribute::ATT_REAL_NAME_SECURITY_GROUP
        return false if self.real_name.blank?
      when UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP
        #KS- all you need to calculate age is the year, all the rest is icing
        return false if self.get_att_value(UserAttribute::ATT_BIRTH_YEAR).blank?
      when UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP
        return false if self.description.blank?
      when UserAttribute::ATT_GENDER_SECURITY_GROUP
        return false if self.get_att_value(UserAttribute::ATT_GENDER).blank?
      when UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP
        return false if self.get_att_value(UserAttribute::ATT_RELATIONSHIP_STATUS).blank?
      when UserAttribute::ATT_EMAIL_SECURITY_GROUP
        #KS- don't do anything, this is just so we don't raise an exception
      else
        #KS- this means we got an unexpected attribute, raise an exception
        raise "Error: unrecognized security attribute #{security_group} in User#ok_to_show_att?"
    end

    #KS- get the security relationship between this user and the viewing user
    user_relation = User.get_security_relationship(self, viewing_user)

    #KS- get the privacy setting for the given security group
    privacy_setting = get_att_value(UserAttribute::ATT_SECURITY, security_group)

    #KS- if the privacy setting is somehow nil, don't allow viewing; otherwise
    #make sure privacy is equal to or less restrictive than the user relation
    return !privacy_setting.nil? && privacy_setting <= user_relation
  end

  #KS- use this to see if there's any about me info that this user wants
  #to display to the viewing user
  #the current list of stuff viewable in about me is:
  # real name
  # email
  # gender
  # relationship status
  # age
  # description
  def has_about_me_info?(viewing_user)
    result = ok_to_show_att?(UserAttribute::ATT_REAL_NAME_SECURITY_GROUP, viewing_user) ||
      ok_to_show_att?(UserAttribute::ATT_EMAIL_SECURITY_GROUP, viewing_user) ||
      ok_to_show_att?(UserAttribute::ATT_GENDER_SECURITY_GROUP, viewing_user) ||
      ok_to_show_att?(UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP, viewing_user) ||
      ok_to_show_att?(UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP, viewing_user) ||
      ok_to_show_att?(UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP, viewing_user)
    return result
  end

  #KS- is this user registered or unregistered?
  def get_user_type
    if salted_password.empty?
      return USER_TYPE_UNREGISTERED
    else
      return USER_TYPE_REGISTERED
    end
  end

  #KS- convenience method that wraps get_user_type
  def registered?
    get_user_type == USER_TYPE_REGISTERED
  end

  def initialize(attributes = nil)
    super
    @new_password = false
    self.suppress_uniqueness_validation = false
    build_planner(:name => 'default', :owner => self, :visibility_type => SkobeeConstants::PRIVACY_LEVEL_PUBLIC)
    @administrator = false

    #KS- set default privacy settings for atts
    set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE, UserAttribute::ATT_REAL_NAME_SECURITY_GROUP)
    set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_FRIENDS, UserAttribute::ATT_EMAIL_SECURITY_GROUP)
    set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_PRIVATE, UserAttribute::ATT_ZIP_SECURITY_GROUP)
    set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE, UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP)
    set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE, UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP)
    set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE, UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP)
    set_att(UserAttribute::ATT_SECURITY, SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE, UserAttribute::ATT_GENDER_SECURITY_GROUP)

    #KS- set default notification settings
    set_notifications_to_default
  end

  #KS- set the user's notification settings to the defaults for an unregistered user
  def set_notifications_to_unregistered_defaults
    set_att(UserAttribute::ATT_REMIND_BY_EMAIL, true)
    set_att(UserAttribute::ATT_INVITE_NOTIFICATION_OPTION, UserAttribute::INVITE_NOTIFICATION_ALWAYS)
    set_att(UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION, UserAttribute::PLAN_MODIFIED_ALWAYS)
    set_att(UserAttribute::ATT_PLAN_COMMENTED_NOTIFICATION_OPTION, UserAttribute::FALSE_USER_ATT_VALUE)
    set_att(UserAttribute::ATT_CONFIRMED_PLAN_REMINDER_OPTION, UserAttribute::CONFIRMED_PLAN_REMINDER_ALWAYS)
    set_att(UserAttribute::ATT_REMINDER_HOURS, 1)
    set_att(UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_OPTION, UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_NEVER)
    set_att(UserAttribute::ATT_USER_COMMENTED_NOTIFICATION_OPTION, UserAttribute::FALSE_USER_ATT_VALUE)
  end

  #KS- set the user's notification settings back to their defaults
  def set_notifications_to_default
    set_att(UserAttribute::ATT_REMIND_BY_EMAIL, UserAttribute::DEFAULT_REMIND_BY_EMAIL)
    set_att(UserAttribute::ATT_INVITE_NOTIFICATION_OPTION, UserAttribute::DEFAULT_INVITE_NOTIFICATION)
    set_att(UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION, UserAttribute::DEFAULT_PLAN_MODIFIED_NOTIFICATION)
    set_att(UserAttribute::ATT_PLAN_COMMENTED_NOTIFICATION_OPTION, UserAttribute::DEFAULT_PLAN_COMMENTED_NOTIFICATION)
    set_att(UserAttribute::ATT_CONFIRMED_PLAN_REMINDER_OPTION, UserAttribute::DEFAULT_CONFIRMED_PLAN_REMINDER)
    set_att(UserAttribute::ATT_REMINDER_HOURS, UserAttribute::DEFAULT_REMINDER_HOURS)
    set_att(UserAttribute::ATT_ADDED_AS_FRIEND_NOTIFICATION_OPTION, UserAttribute::DEFAULT_ADDED_AS_FRIEND_NOTIFICATION)
    set_att(UserAttribute::ATT_USER_COMMENTED_NOTIFICATION_OPTION, UserAttribute::DEFAULT_USER_COMMENTED_NOTIFICATION)
  end

  #KS- set the user's privacy settings back to their defaults
  def set_privacy_to_default
    #KS- the plans privacy is different from the others in that it is stored directly in the planners table
    self.planner.visibility_type = UserAttribute::DEFAULT_PLANNER_VISIBILITY_TYPE

    #KS- set the attributes in the user_atts table to their defaults
    set_att(UserAttribute::ATT_SECURITY, UserAttribute::DEFAULT_REAL_NAME_SECURITY, UserAttribute::ATT_REAL_NAME_SECURITY_GROUP)
    set_att(UserAttribute::ATT_SECURITY, UserAttribute::DEFAULT_EMAIL_SECURITY, UserAttribute::ATT_EMAIL_SECURITY_GROUP)
    set_att(UserAttribute::ATT_SECURITY, UserAttribute::DEFAULT_BIRTHDAY_AGE_SECURITY, UserAttribute::ATT_BIRTHDAY_AGE_SECURITY_GROUP)
    set_att(UserAttribute::ATT_SECURITY, UserAttribute::DEFAULT_RELATIONSHIP_STATUS_SECURITY, UserAttribute::ATT_RELATIONSHIP_STATUS_SECURITY_GROUP)
    set_att(UserAttribute::ATT_SECURITY, UserAttribute::DEFAULT_DESCRIPTION_SECURITY, UserAttribute::ATT_DESCRIPTION_SECURITY_GROUP)
    set_att(UserAttribute::ATT_SECURITY, UserAttribute::DEFAULT_GENDER_SECURITY, UserAttribute::ATT_GENDER_SECURITY_GROUP)
  end

  def administrator?
    return USER_TYPE_ADMIN == user_type
  end

  #KS- convenience function to get the zip code
  def zipcode
    return get_att_value(UserAttribute::ATT_ZIP)
  end

  def zipcode=(rval)
    set_att(UserAttribute::ATT_ZIP, rval)
    if rval.blank?
      self.time_zone = DEFAULT_TIME_ZONE
    else
      self.time_zone = User.get_timezone_from_zip(rval)
    end
  end

  #MES- Is this user an "international" user?
  def international?
    #MES- Is their zip code the special international zip code?
    return INTL_USER_ZIPCODE_STR == zipcode
  end

  #MES- Perform various operations that should be done after a new User is created
  def after_create
    #MES- If a zipcode is set, record it.  This is special because
    # the zipcode is NOT stored in the User object- it's a user_att.
    if !@zipcode.blank?
      self.set_att UserAttribute::ATT_ZIP, @zipcode
    end
  end

  #KS- takes in a user and an email address (string). looks up the user that has the
  #email as a primary email address and merges their plans over to merger. after this
  #everything from the other user is deleted
  def self.merge(merger, mergee)
    #KS- sql to grab each planner_plan entry owned by the mergee
    find_planners_plans_sql_string = <<-END_OF_STRING
      SELECT
        planner_id, plan_id, ownership
      FROM
        planners_plans
      WHERE
        planner_id = :planner_id
    END_OF_STRING

    find_planners_plans_sql_params = {:planner_id => mergee.planner.id}
    find_planners_plans_sql = [find_planners_plans_sql_string, find_planners_plans_sql_params]

    #KS- grab all of the mergee's planners_plans entries
    mergee_planners_plans = perform_select_all_sql(find_planners_plans_sql)

    #KS- sql to update the planners_plans so that each of them is owned by the new user
    update_planners_plans_sql_string = <<-END_OF_STRING
      UPDATE
        planners_plans
      SET
        user_id_cache = :user_id,
        planner_id = :new_planner_id
      WHERE
        planner_id = :original_planner_id AND
        plan_id = :original_plan_id
    END_OF_STRING

    #KS- this is used when we need to set the ownership of a plan to the merger
    #because the mergee owns it and otherwise we'd have a plan with no ownership
    #when the mergee gets all their junk deleted
    update_plan_ownership_string = <<-END_OF_STRING
      UPDATE
        planners_plans
      SET
        ownership = 1
      WHERE
        planner_id = :merger_planner_id AND
        plan_id = :merger_plan_id
    END_OF_STRING

    update_planners_plans_sql_params = {:user_id => merger.id, :new_planner_id => merger.planner.id}
    mergee_planners_plans.each{|planner_plan|

      update_planners_plans_sql_params[:original_planner_id] = planner_plan['planner_id']
      update_planners_plans_sql_params[:original_plan_id] = planner_plan['plan_id']

      begin
        perform_update_sql([ update_planners_plans_sql_string, update_planners_plans_sql_params ])
      rescue ActiveRecord::StatementInvalid => exc
        #KS- if there was an exception that means there was a duplicate planner_id/plan_id key
        #but we're not done -- have to copy the ownership over if the mergee was the owner
        #otherwise we could end up with a plan that has no owner (not very nice)
        if planner_plan['ownership'] == ApplicationHelper::DB_TRUE_VALUE_STRING
          update_plan_ownership_params = { :merger_planner_id => merger.planner.id, :merger_plan_id => planner_plan['plan_id'] }

          perform_update_sql([update_plan_ownership_string, update_plan_ownership_params])
        end
      end
    }

    #KS- merge over or delete the rest of the merged from user's data
    User.handle_dangling_data(merger, mergee)
  end

  #KS- handle dangling data from each of these tables in the following ways:
  #comments: change the owner_id from the merged from user to the merged to user
  #emails: delete anything where the user_id is the merged from user's id
  #feedbacks: change the user_id from the merged from user to the merged to user
  #pictures: delete anything where the id is the merged from user's id
  #plan_changes: change the owner id from the merged from user to the merged to user
  #planners: delete anything where the user_id is the merged from user's id
  #sessions: delete anything where the id is the merged from user's id
  #user_atts: delete anything where the user_id is the merged from user's id
  #user_contacts: delete anything where the user_id is the merged from user's id
  #users: delete anything where the id is the merged from user's id
  #users_fulltext: delete anything where the user_id is the merged from user's id
  def self.handle_dangling_data(merged_to_user, merged_from_user)
    #KS- we can use these hashes for all of the updates/deletes
    both_hash = {:merged_from_user => merged_from_user.id, :merged_to_user => merged_to_user.id}
    just_merged_from_hash = {:merged_from_user => merged_from_user.id}
    just_merged_to_hash = {:merged_to_user => merged_to_user.id}

    #KS- move the comments over
    update_comments_sql = "UPDATE comments SET owner_id = :merged_to_user WHERE owner_id = :merged_from_user"
    perform_update_sql([update_comments_sql, both_hash])

    #KS- move the confirmed emails over, delete all others, delete duplicates
    delete_emails_sql = "DELETE FROM emails WHERE user_id = :merged_from_user AND confirmed != 1"
    perform_delete_sql([delete_emails_sql, just_merged_from_hash])
    update_emails_sql = "UPDATE emails SET emails.primary = 0, user_id = :merged_to_user WHERE user_id = :merged_from_user"
    perform_update_sql([update_emails_sql, both_hash])
    delete_duplicates_sql = <<-END_OF_STRING
      DELETE FROM
        emails as e1
      USING
        emails as e1,
        emails as e2
      WHERE
        e1.id != e2.id AND
        e1.address = e2.address AND
        e1.confirmed = 0 AND
        e1.user_id = :merged_to_user AND
        e2.user_id = :merged_to_user
    END_OF_STRING
    perform_delete_sql([delete_duplicates_sql, just_merged_to_hash])

    #KS- sql to update the invitees of the old user so that they are all labelled as being invited
    #by the new user
    update_invitees_sql_string = <<-END_OF_STRING
      UPDATE
        users
      SET
        invited_by = :merged_to_user
      WHERE
        invited_by = :merged_from_user
    END_OF_STRING
    perform_update_sql([update_invitees_sql_string, both_hash])

    #KS- move the feedbacks over
    update_feedbacks_sql = "UPDATE feedbacks SET user_id = :merged_to_user WHERE user_id = :merged_from_user"
    perform_update_sql([update_feedbacks_sql, both_hash])

    #KS- delete the pictures
    delete_images_sql = "DELETE FROM pictures WHERE id = (SELECT image_id FROM users WHERE users.id = :merged_from_user)"
    perform_delete_sql([delete_images_sql, just_merged_from_hash])
    delete_thumbnails_sql = "DELETE FROM pictures WHERE id = (SELECT thumbnail_id FROM users WHERE users.id = :merged_from_user)"
    perform_delete_sql([delete_thumbnails_sql, just_merged_from_hash])

    #KS- move the places over
    update_places_sql = "UPDATE places SET user_id = :merged_to_user WHERE user_id = :merged_from_user"
    perform_update_sql([update_places_sql, both_hash])

    #KS- move the plan_changes over
    update_plan_changes_sql = "UPDATE plan_changes SET owner_id = :merged_to_user WHERE owner_id = :merged_from_user"
    perform_update_sql([update_plan_changes_sql, both_hash])

    #KS- delete the planners
    delete_planners_sql = "DELETE FROM planners WHERE user_id = :merged_from_user"
    perform_delete_sql([delete_planners_sql, just_merged_from_hash])

    #KS- delete any planners_plans entries that weren't switched over
    delete_planners_plans_sql = "DELETE FROM planners_plans WHERE user_id_cache = :merged_from_user"
    perform_delete_sql([delete_planners_plans_sql, just_merged_from_hash])

    #KS- delete the user_atts
    delete_user_atts_sql = "DELETE FROM user_atts WHERE user_id = :merged_from_user"
    perform_delete_sql([delete_user_atts_sql, just_merged_from_hash])

    #KS- delete from user_contacts (both people they have marked as a contact and people who
    #have marked them as a contact)
    delete_user_contacts_sql = "DELETE FROM user_contacts WHERE user_id = :merged_from_user"
    perform_delete_sql([delete_user_contacts_sql, just_merged_from_hash])
    delete_user_contacts_inverse_sql = "DELETE FROM user_contacts WHERE contact_id = :merged_from_user"
    perform_delete_sql([delete_user_contacts_inverse_sql, just_merged_from_hash])

    #KS- delete entry in user table
    delete_user_sql = "DELETE FROM users WHERE id = :merged_from_user"
    perform_delete_sql([delete_user_sql, just_merged_from_hash])
  end

  def email_key_combo_legit?(email_address, key)
    return false if token_expired?

    sql = <<-END_OF_STRING
      SELECT
        users.*
      FROM
        users, emails
      WHERE
        users.id = :id AND security_token = :security_token
        AND emails.address = :email
        AND users.id = emails.user_id
    END_OF_STRING

    user_array = User.find_by_sql [sql, {:security_token => key, :id => id, :email => email_address}]

    if user_array.length > 1
      #KS- raise an exception because there should only ever be one
      raise "Error: more than one user with same security token and id in UserController#confirm_email"
    end

    return user_array.length == 1
  end

  def confirm_email(email_address, key)
    if email_key_combo_legit?(email_address, key)
      email_array =
        Email.find(:all,
                   :conditions => ['address = :address AND user_id = :user_id', {:address => email_address, :user_id => self.id}])

      #KS- raise an exception if there was more than one email with the same address for the given user
      if email_array.length > 1
        raise "Error: should not find more than one email address with the address #{address} for user #{id}"
      end

      email = email_array[0]
      email.confirmed = Email::CONFIRMED
      email.save
    end
  end

  #KS- this now just returns the login. i will leave this method here for now in case we change our minds about
  # what we want to do in the near future.
  def display_name
    login
  end

  #KS- overriding find_by_email to use the underlying emails table
  def self.find_by_email(email)
    sql = <<-END_OF_STRING
      SELECT
        DISTINCT users.*
      FROM
        users, emails
      WHERE
        emails.address = :address AND
        emails.user_id = users.id AND
        emails.confirmed = 1
    END_OF_STRING

    users_array = find_by_sql [sql, {:address => email}]

    if users_array.length > 1
      raise "Error in User::find_by_email: #{users_array.length} users found with email #{email}"
    elsif users_array.length == 1
      return users_array[0]
    else
      return nil
    end
  end

  #KS- get the primary Email object associated with this user
  def email_object
    primary_email_array = emails.reject{|email| email.primary != Email::PRIMARY }

    #KS- if there is more than one primary email, we have database corruption, so
    #throw an exception
    if primary_email_array.length > 1
      emails_string = ''
      primary_email_array.each{|email| emails_string = "#{emails_string} #{email.address}"}
      raise "Error in User.email: database corrupted! #{primary_email_array.length} primary emails found for user #{self.id} (#{self.login}) -- (#{emails_string})"
    end

    if primary_email_array.length == 1
      return primary_email_array[0]
    else
      return nil
    end
  end

  #KS- convenience method to calculate the user's age from their birthday fields
  def age
    time_now = Time.now()

    birth_year = get_att_value(UserAttribute::ATT_BIRTH_YEAR).nil? ? nil : get_att_value(UserAttribute::ATT_BIRTH_YEAR).to_i
    birth_month = get_att_value(UserAttribute::ATT_BIRTH_MONTH).nil? ? nil : get_att_value(UserAttribute::ATT_BIRTH_MONTH).to_i
    birth_day = get_att_value(UserAttribute::ATT_BIRTH_DAY).nil? ? nil : get_att_value(UserAttribute::ATT_BIRTH_DAY).to_i

    User.age_helper(birth_year, birth_month, birth_day, time_now.year, time_now.month, time_now.day)
  end

  #KS- do the actual age calculations using this function (easier to test this way)
  def self.age_helper(birth_year, birth_month, birth_day, now_year, now_month, now_day)
    #KS- don't even bother if the year is nil
    if birth_year.nil?
      return nil
    end

    #KS- if the field isn't in the database, effectively ignore the data
    year_diff = now_year - birth_year
    month_diff = birth_month.nil? ? 0 : now_month - birth_month
    day_diff = birth_day.nil? ? 0 : now_day - birth_day

    #KS- account for days earlier in the year
    if month_diff < 0
      year_diff -= 1
    elsif month_diff == 0 && day_diff < 0
      year_diff -= 1
    end

    return year_diff
  end

  #KS- spit out a munged email address that's appropriate for display in the
  #about me UI
  def email_formatted_for_display
    return User.email_formatted_for_display_helper(self.email)
  end

  def self.email_formatted_for_display_helper(email_string)
    return email_string.email_formatted_for_display
  end

  #KS- get the primary email address. this is here to support the existing
  #usage of "user.email" as accessing the primary email address.
  def email
    primary_email = email_object
    if primary_email.nil?
      return nil
    else
      return primary_email.address
    end
  end

  #KS- assign the primary email address. this is here to support the existing
  #usage of "user.email = " as assignment to the primary email address.
  def email=(rval)
    primary_email = email_object

    if primary_email.nil?
      primary_email = Email.new
      primary_email.address = rval
      primary_email.primary = Email::PRIMARY
      emails << primary_email
    else
      primary_email.address = rval
    end
  end

  #KS- get all the user's thumbnails
  def thumbnails
    return pictures.select{ |pic| pic.size_type == Picture::SIZE_THUMBNAIL }
  end

  #KS- get all the user's medium pictures
  def medium_images
    return pictures.select{ |pic| pic.size_type == Picture::SIZE_MEDIUM }
  end

  #KS- get the confirmedness of the user's primary email. this is here to support
  #the existing usage of "user.verified" by using the new underlying emails table
  def verified
    email_object.confirmed
  end

  #KS- assign the confirmedness of the user's primary email. this is here to support
  #the existing usage of "user.verified = " by using the new underlying emails table.
  def verified=(rval)
    primary_email = email_object
    primary_email.confirmed = rval
    primary_email.save
  end

  #KS- this will give you back the first name followed by a space followed by the
  #last name if both first name and last name are available. if only one is available,
  #that one will be returned. if neither is available, it will return login
  def full_name
    if !real_name.nil? && !real_name.empty?
      return real_name
    else
      return login
    end
  end

  #MES- Simliar to 'full_name' but returns the full name concatenated
  # with the login, like 'Michael Smedberg (michaels)'.  If the real
  # name isn't set, the login is returned.
  def full_name_and_login
    if !real_name.nil? && !real_name.empty?
      return "#{real_name} (#{login})"
    else
      return login
    end
  end

  #MES- selected_clipboard_contacts is a subset of contacts that has a status of
  # selected or checked.  It's a simple array- you can't do push_with_attributes, etc.
  def selected_clipboard_contacts
    contacts.select { | ctct | SELECTED_CLIPBOARD_STATUSES.include? ctct.clipboard_status.to_i }
  end

  #MES- checked_clipboard_contacts is a subset of contacts that has a status of
  # checked.  It's a simple array- you can't do push_with_attributes, etc.
  def checked_clipboard_contacts
    contacts.select { | ctct | CLIPBOARD_STATUS_CHECKED == ctct.clipboard_status.to_i }
  end

  #MES- friends is a subset of contacts that has a friend_status of
  # FRIEND_STATUS_FRIEND.  It's a simple array- you can't do push_with_attributes, etc.
  def friends
    friends = contacts.select { | ctct | FRIEND_STATUS_FRIEND == ctct.friend_status.to_i }

    #KS- sort in alphabetical order of downcased login
    friends.sort!{|a, b|
      a.login.downcase <=> b.login.downcase
    }

    return friends
  end

  #MGS- contacts is a subset of friends that has a friend_status of
  # FRIEND_STATUS_CONTACT.  It's a simple array- you can't do push_with_attributes, etc.
  def friend_contacts
    friend_contacts = contacts.select { | ctct | FRIEND_STATUS_CONTACT == ctct.friend_status.to_i }

    #KS- sort in alphabetical order of downcased login
    friend_contacts.sort!{|a, b|
      a.login.downcase <=> b.login.downcase
    }

    return friend_contacts
  end

  #MGS- return the combined collection of friends and contacts
  def friends_and_contacts
    combined_contacts = self.friends + self.friend_contacts
    return combined_contacts.sort!{|a, b| a.login.downcase <=> b.login.downcase}
  end

  def add_or_update_contact(user, params = {})
    #MGS- This method should be used for all contact changes.
    # Neither update_attributes nor push_or_update attributes
    # should be called for contacts directly.

    #MGS- a user wasn't passed in try to use the string/integer to find the user
    if !user.kind_of? User
      user = User.find(user)
    end

    #MGS- helper method to set or update contact status and/or friend status
    # params can be anything that needs to be updated on the user_contacts table
    # usually contact status and friend status.
    # This helper also checks to see if a new entry is created in the user_contacts table
    # and updates the contact_created_at column accordingly.
    res = self.contacts.push_or_update_attributes(user, params)
    #MES- If this made a new record, set the contact_created_at for it
    if res
      self.contacts.update_attributes(user, :contact_created_at => Time.new)
    end

    #MGS- refresh the contacts list from the db, the db will set a default CLIPBOARD_STATUS if one was not explicitly set
    self.contacts(true)
  end

  #KS- return true if this user considers other_user to have a preexisting relationship with them
  def relationship_exists(other_user_id)
    sql = <<-END_OF_STRING
      SELECT * FROM user_contacts WHERE user_id = ? AND contact_id = ?
    END_OF_STRING

    array = User.find_by_sql([sql, self.id, other_user_id])

    if array.length > 0
      return true
    else
      return false
    end
  end

  def add_contacts_from_plan(pln)
    #MES- Make sure that each user associated with the
    # plan is recorded as a contact for the current user
    if pln.is_a? ActiveRecord::Base
      pln_id = pln.id
    else
      pln_id = pln.to_i
    end

    cal_id = planner.id

    #MES- Add any contacts that are new due to acceptances of this plan
    insert_confirmed_attendees_for_pln_sql = <<-END_OF_STRING
      INSERT INTO user_contacts (user_id, contact_id, connections, contact_created_at)
      SELECT
        ?, c.user_id, count(*), UTC_TIMESTAMP()
      FROM
        planners AS c,
        planners_plans AS ce
      WHERE
        c.id != ? AND
        c.id = ce.planner_id AND
        ce.plan_id = ? AND
        ce.cal_pln_status IN (0, 2) AND
        NOT EXISTS (
          SELECT *
          FROM
            user_contacts
          WHERE
            user_contacts.user_id = ? AND
            user_contacts.contact_id = c.user_id
        )
      GROUP BY c.user_id
    END_OF_STRING

    perform_update_sql([insert_confirmed_attendees_for_pln_sql, self.id, cal_id, pln_id, self.id], "Adding new contacts for user #{self.id} due to acceptance of plan #{pln_id}")

    #MES- The contacts array is now potentially incorrect, invalidate it
    contacts.reset
  end

  def set_att(att_id, att_value, group_id=nil)
    att_id = att_id.to_i
    #KS- try to look up the group_id if it's nil
    #(note that the only time a group_id will probably be manually specified is if it
    #is a security setting)
    if group_id.nil?
      group_id = UserAttribute::GROUP_MAPPINGS[att_id]
    end


    #MES- Set the att if it exists, or make it and set it if not
    att = find_att(att_id, group_id)
    if att
      att.att_value = att_value
      att.group_id = group_id
      att.save
    else
      user_atts.create(:att_id => att_id, :att_value => att_value, :group_id => group_id)
    end

    att_changed(att_id, att_value)
  end

  #KS- delete an attribute
  def delete_att(att_id)
    return UserAttribute.delete_all(["att_id = ? AND user_id = ?", att_id, id])
  end

  #MES- Get the value for the indicated attribute
  def get_att_value(att_id, group_id = nil)
    #KS- try to look up the group_id if it's nil
    #(note that the only time a group_id will probably be manually specified is if it
    #is a security setting)
    if !UserAttribute::GROUP_MAPPINGS[att_id].nil?
      group_id = UserAttribute::GROUP_MAPPINGS[att_id]
    end

    att = find_att(att_id, group_id)
    return nil if att.nil?

    #KS- if att.att_value is a String, do some hacked-up type conversion
    if att.att_value.kind_of?(String)
      #KS- if the attribute is an integer type, convert to an integer before returning
      #for now we only handle Integer types. everything else we just return the value
      type = UserAttribute::ATT_TYPES[att.att_id]
      if type == Integer
        att.att_value = att.att_value.to_i
      end
    end

    return att.att_value
  end

  def self.get_att_privacy_default(att_id)
    return PRIVACY_DEFAULT_MAP[att_id]
  end

  def att_changed(att_id, new_value)
    #MES- Called whenever the value of an attribute has been changed.
    # Handles any related updates that are necessary.
    case att_id
      when UserAttribute::ATT_ZIP:
        #MES- The home address changed, we need to change the proximity
        # search info to correspond to the new location.
        set_geocode_from_location(new_value)
    end
  end

  def set_geocode_from_location(location)
    #MES- Set the bounding box for location searches (i.e. the
    # lat_max, lat_min, long_max, and long_min settings) based
    # on the new location.

    #MES- If they specifically didn't give a location, blank out the bounding box
    if location.nil? || location.empty?
      self.lat, self.long, self.lat_max, self.lat_min, self.long_max, self.long_min = nil, nil, nil, nil, nil, nil
      return true
    else
      geocode_info = GeocodeCacheEntry.find_loc(location)
      #MES- Did we get the geocode info?
      if !geocode_info.nil?
        #MES- Yup, store it and turn it into a bounding box
        self.lat, self.long = geocode_info.lat, geocode_info.long
        bounding_box = GeocodeCacheEntry.get_bounding_box_array(geocode_info, DEFAULT_MAX_PROX_SEARCH_MILES)
        self.lat_max, self.lat_min, self.long_max, self.long_min = bounding_box
        return true
      end
    end

    #MES- The geocoding wasn't successful
    return false
  end

  ####################################################################################
  ######  User finders
  ####################################################################################

  def self.find_regulars(userid, max = 10, sort_by_name = false)
    #MES- We want to find the users that userid regularly
    #  shares plans with.
    if userid.kind_of? User
      userid = userid.id
    end
    
    #MES- What should we sort by?  The default is to sort by connections
    sort_by = 'user_contacts.connections DESC'
    sort_by = "IFNULL(#{User.table_name}.real_name, #{User.table_name}.login)" if sort_by_name

    sql = <<-END_OF_STRING
      SELECT
        #{User.table_name}.*
      FROM
        #{User.table_name},
        user_contacts
      WHERE
        user_contacts.user_id = ? AND
        user_contacts.contact_id = users.id
      ORDER BY
        #{sort_by}
      LIMIT ?
    END_OF_STRING

    self.find_by_sql [sql, userid, max]
  end

  def self.find_friends_inverse(userid)
    #MGS- find the users that have added this user to their friends list
    #MGS TODO- does this need to be cached on the User object?
    if userid.kind_of? User
      userid = userid.id
    end

    sql = <<-END_OF_STRING
      SELECT
        u.*
      FROM
        #{User.table_name} AS u,
        user_contacts AS uc
      WHERE
        u.id = uc.user_id AND
        uc.contact_id = ? AND
        uc.friend_status =  #{FRIEND_STATUS_FRIEND}
      ORDER BY
        u.real_name DESC
    END_OF_STRING

    self.find_by_sql [sql, userid]
  end

  def self.find_contacts_inverse(userid)
    #MGS- find the users that have added this user to their contacts list
    #MGS TODO- does this need to be cached on the User object?
    if userid.kind_of? User
      userid = userid.id
    end

    sql = <<-END_OF_STRING
      SELECT
        u.*
      FROM
        #{User.table_name} AS u,
        user_contacts AS uc
      WHERE
        u.id = uc.user_id AND
        uc.contact_id = ? AND
        uc.friend_status IN (?)
      ORDER BY
        u.login
      LIMIT ?
    END_OF_STRING
    #MGS- limit to 100 until we offer paging
    self.find_by_sql [sql, userid, [FRIEND_STATUS_CONTACT, FRIEND_STATUS_FRIEND], 100]
  end

  def self.find_users_and_plans_needing_reminders(now = nil)
    #MES- Find the users and plans that require reminders
    # The results are returned as an array of [user, [plan1, plan2, ..., planx]] arrays.

    #MES- NOTE: There is MySQL specific logic here!
    #TODO: add SMS notification
    sql = <<-END_OF_STRING
      SELECT DISTINCT #{user_plan_cols}
      FROM
          #{User.table_name} AS u,
          #{Planner.table_name} AS c,
          #{UserAttribute.table_name} AS ua1,
          #{UserAttribute.table_name} AS ua2,
          #{UserAttribute.table_name} AS ua3,
          planners_plans AS ce,
          #{Plan.table_name} AS e
      WHERE
           u.id = c.user_id AND
           ua1.user_id = u.id AND ua1.att_id = \'#{UserAttribute::ATT_REMINDER_HOURS}\' AND ua1.att_value IS NOT NULL AND
           (ua2.user_id = u.id AND ua2.att_id = \'#{UserAttribute::ATT_REMIND_BY_EMAIL}\' AND ua2.att_value = \'#{UserAttribute::TRUE_USER_ATT_VALUE}\') AND
           (ua3.user_id = u.id AND ua3.att_id = \'#{UserAttribute::ATT_CONFIRMED_PLAN_REMINDER_OPTION}\' AND ua3.att_value = \'#{UserAttribute::CONFIRMED_PLAN_REMINDER_ALWAYS}\') AND
           c.id = ce.planner_id AND
           ce.plan_id = e.id AND
           ce.reminder_state IS NULL AND
           (
             (u.salted_password != '' AND ce.cal_pln_status IN (?)) OR
             (u.salted_password = '' AND ce.cal_pln_status IN (?))
           ) AND
           e.fuzzy_start > #{now.nil? ? 'UTC_TIMESTAMP()' : '?'} AND
           (
             (e.fuzzy_start < DATE_ADD(#{now.nil? ? 'UTC_TIMESTAMP()' : '?'}, INTERVAL CAST(ua1.att_value AS SIGNED) HOUR) AND
              e.created_at < DATE_SUB(e.fuzzy_start, INTERVAL CAST(ua1.att_value AS SIGNED) HOUR) AND
              e.fuzzy_start = e.start) OR
             (e.fuzzy_start != e.start AND
              e.fuzzy_start < DATE_ADD(#{now.nil? ? 'UTC_TIMESTAMP()' : '?'}, INTERVAL #{POSTPONE_EXPIRY_WINDOW} HOUR))
           )

      ORDER BY
           u.id, e.fuzzy_start ASC
    END_OF_STRING

    #MES- Perform the SQL
    #MES- The logic here is stolen from find_by_sql
    result = []
    last_user_id = -1
    sql_args_array = [sql]

    #KS- should only send reminders to registered users if they are in or altered
    sql_args_array <<  Plan::STATUSES_ACCEPTED

    #KS- should send reminders to unregistered users if they are in, altered OR invited
    sql_args_array << Plan::STATUSES_ACCEPTED_OR_INVITED

    #KS- put it in three times because now we need it for the constraining to future
    #clause (no past events) as well as the fuzzy clause and the solid clause
    sql_args_array << now << now << now if !now.nil?

    connection.select_all(sanitize_sql(sql_args_array), "#{name} find_users_and_plans_needing_reminders").collect! do |record|
      #MES- For each record, pick out the columns that are relevant to the User
      user_hash = record.find_and_strip_prefixes("#{User.table_name}_")
      #MES- Same for plan
      plan_hash = record.find_and_strip_prefixes("#{Plan.table_name}_")

      #MES- Have we already seen this user?
      if last_user_id == user_hash['id'].to_i
        #MES- A repeat; we've seen this user before
        result[result.length - 1][1] << Plan.instantiate(plan_hash)
      else
        #MES- A user we haven't seen before
        result << [instantiate(user_hash), [Plan.instantiate(plan_hash)]]
        last_user_id = user_hash['id'].to_i
      end
    end

    return result
  end

  def self.find_recently_added_me_as_friend(userid, max = 5)
    #MES- Find the users that have recently added the indicated user as a friend, but
    # who are NOT friends or contacts of mine
    if userid.kind_of? User
      userid = userid.id
    end

    sql = <<-END_OF_STRING
      SELECT
        u.*
      FROM
        #{User.table_name} AS u,
        user_contacts AS uc
      WHERE
        uc.user_id = u.id AND
        uc.contact_id = ? AND
        uc.friend_status IN (?) AND
        NOT EXISTS
        (
         SELECT *
         FROM user_contacts
         WHERE
           user_id = ? AND
           contact_id = uc.user_id
        )
      ORDER BY
        uc.contact_created_at DESC
      LIMIT ?
    END_OF_STRING

    self.find_by_sql [sql, userid, [User::FRIEND_STATUS_CONTACT, User::FRIEND_STATUS_FRIEND], userid, max]
  end

  #KS- find a user by a primary email address
  def self.find_by_primary_email_address(address)
    sql = <<-END_OF_STRING
      SELECT
        users.*
      FROM
        users, emails
      WHERE
        users.id = emails.user_ID AND
        emails.primary = 1 AND
        emails.address = :address
    END_OF_STRING

    query_params = {:address => address}

    results = self.find_by_sql [sql, query_params]

    if !results.nil? && results.length > 0
      return results[0]
    else
      return nil
    end
  end

  #KS- this method doesn't respect security. it's currently being used to grab users
  #who are "I'll Be There"ed on an event with the purpose of notifying them of plan changes
  def self.find_associated_with_plan(plan_id, status_array = Plan::STATUSES_ACCEPTED )
    if plan_id.is_a?(Plan)
      plan_id = plan_id.id
    end

    sql = <<-END_OF_STRING
      SELECT
        DISTINCT users.*
      FROM
        users, planners, planners_plans
      WHERE
        planners_plans.plan_id = :plan_id AND
        users.id = planners.user_id AND
        planners.id = planners_plans.planner_id AND
        planners_plans.cal_pln_status IN (:status_array)
    END_OF_STRING

    query_params = { :plan_id => plan_id, :status_array => status_array }

    self.find_by_sql [sql, query_params]
  end

  def self.accepted_users_have_relationship?(user_id, plan_id)
    #MGS- return true if acccepted users have friend/contact relationship with viewing user
    # This is used as a security query of sorts to enable people who are not on the invite list
    # of a plan to comment on the plan, but only if someone who has set them as a
    # friend or contact has accepted the plan.

    #MGS- if a plan object was passed instead of an id, handle that
    if plan_id.kind_of? Plan
      plan_id = plan_id.id
    end

    #MGS- if a plan object was passed in instead of an id, handle that
    if user_id.kind_of? User
      user_id = user_id.id
    end

    sql = <<-END_OF_STRING
      SELECT
        COUNT(*) AS CT
      FROM
        planners_plans pp,
        user_contacts uc,
        #{User.table_name}  u
      WHERE
        uc.user_id = u.id AND
        pp.user_id_cache = uc.user_id AND
        pp.plan_id = ? AND
        uc.contact_id = ? AND
        pp.cal_pln_status IN (?) AND
        uc.friend_status IN (?)
    END_OF_STRING

    #MGS- is the count greater than zero?
    0 < self.perform_select_all_sql([sql, plan_id, user_id, Plan::STATUSES_ACCEPTED, [FRIEND_STATUS_CONTACT, FRIEND_STATUS_FRIEND]])[0]['CT'].to_i
  end

  def self.find_attended_place(place_id, max = 5)
#MES- TODO: Should this ALSO include users that have planners for which the
# "current" user is a friend, and the visibility of the planner is "friends"?
    #MES- Find plans that are publicly viewable and occur at the indicated place.
    # Limit to the first *max* users, ordered by ??????

    #MES- Note:  We do NOT check if the place is public.  Finding users for
    # a private place is not currently considered a breach of place security.

    if place_id.is_a?(Place)
      place_id = place_id.id
    end


#MES- TODO: How should this be sorted?
    user_cols = cols_for_select('u')
    sql = <<-END_OF_STRING
      SELECT
        DISTINCT users.*
      FROM
        users, planners, planners_plans
      WHERE
        users.id = planners.user_id AND
        planners.id = planners_plans.planner_id AND
        planners_plans.cal_pln_status IN (?) AND
        planners_plans.place_id_cache = ? AND
        planners_plans.planner_visibility_cache = #{SkobeeConstants::PRIVACY_LEVEL_PUBLIC} AND
        planners_plans.plan_security_cache = #{Plan::SECURITY_LEVEL_PUBLIC}
      ORDER BY
        planners_plans.plan_id DESC
      LIMIT ?
    END_OF_STRING

    self.find_by_sql [sql, Plan::STATUSES_ACCEPTED, place_id, max]

  end

  #KS- finds the security relationship between the viewed and viewing user
  def self.get_security_relationship(viewed_user, viewing_user)
    #KS- start with least permissions
    user_relation = SkobeeConstants::PRIVACY_LEVEL_PUBLIC

    #KS- get the security level that represents the highest level of access the
    #viewing_user has to the viewed_user's details
    if not viewing_user.nil?
      #KS- viewing user is logged in at least, so set user relation to skobee
      user_relation = SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE

      #TODO: handle contacts
      if viewed_user.friends.include?(viewing_user)
        user_relation = SkobeeConstants::PRIVACY_LEVEL_FRIENDS
      elsif viewed_user == viewing_user
        user_relation = SkobeeConstants::PRIVACY_LEVEL_PRIVATE
      end
    end

    return user_relation
  end

  #MGS- find user given either its email or login
  def self.find_by_string(str)
    return nil if str.nil?

    if str.is_email?
      #MGS- this is an email - see if there's a user corresponding to it
      return User.find_by_email(str)
    else
      #MGS- lookup user by login
      return User.find_by_login(str)
    end
  end

  #MES- Find users using fulltext semantics.  Returns an array of matching users.
  def self.find_by_ft(str, user_id_to_exclude, limit = 10)
    #MES- This is similar to find_by_string, but uses fulltext
    # semantics to match the string against logins or real names.
    return [] if (str.nil? || limit < 1)

    if str.is_email?
      #MES- For emails, return an array containing the user if found, or the
      # zero length array.
      usr = User.find_by_email(str)
      #MES- If we got no results OR we got the current user, return []
      return [] if usr.nil? || user_id_to_exclude == usr.id
      #MES- We got a result, return it in an array
      return [usr]
    else
      #MES- Perform a fulltext type query to find the user.
      # We use the special table users_fulltext to perform the query-
      # it contains the textual info about the user and is fulltext
      # indexed.
      sql = <<-END_OF_STRING
        SELECT DISTINCT
          users.*
        FROM
          users, users_fulltext
        WHERE
          users.id = users_fulltext.user_id AND
          MATCH (users_fulltext.searchable) AGAINST (?) AND
          users.id != ?
        LIMIT ?
      END_OF_STRING

      self.find_by_sql [sql, str, user_id_to_exclude, limit]
    end

  end

  ####################################################################################
  ######  Utility functions
  ####################################################################################

  #KS- send the user a notification if their notification settings indicate they
  #want one
  def handle_plan_updated(plan, changes, modifying_user)
    #KS- check notification settings
    if get_att_value(UserAttribute::ATT_REMIND_BY_EMAIL) == 1 &&
       get_att_value(UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION) == UserAttribute::PLAN_MODIFIED_ALWAYS

      UserNotify.deliver_update_notification(self, changes, plan, modifying_user)
    end
  end

  #MES- Similar to handle_plan_updated, but specifically for when a
  # comment was made on the plan
  def handle_plan_comment(plan, change, modifying_user)
    #KS- check notification settings
    if get_att_value(UserAttribute::ATT_REMIND_BY_EMAIL) == 1 &&
        get_att_value(UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION) == UserAttribute::PLAN_MODIFIED_ALWAYS &&
        get_att_value(UserAttribute::ATT_PLAN_COMMENTED_NOTIFICATION_OPTION) == UserAttribute::TRUE_USER_ATT_VALUE

      UserNotify.deliver_plan_comment_notification(self, change, plan, modifying_user)
    end
  end

  def record_notified(plans)
    #MES- plans is an array of plans that the user has been notified of-
    # we should record this so that we don't send them notifications repeatedly.
    plans.each do | pln |
      planner.mark_plan_notified(pln, Planner::PLAN_NOTIFICATION_STATE_NOTIFIED)
    end
  end

  def self.user_plan_cols
    #MES- Columns from the User and Plan table, with prefixes to disambiguate them
    (User.column_names.map { | col | "u.#{col} as #{User.table_name}_#{col}"}).concat((Plan.column_names.map { | col | "e.#{col} as #{Plan.table_name}_#{col}"})).join(', ')
  end


  def update_some(atts)
    connection.update(
      "UPDATE #{self.class.table_name} " +
      "SET #{quoted_comma_pair_list(connection, specified_attributes_with_quotes(atts))} " +
      "WHERE #{self.class.primary_key} = #{quote(id)}",
      "#{self.class.name} Update Some"
    )
  end

  # Returns copy of the attributes hash where all the values have been safely quoted for use in
  # an SQL statement.
  def specified_attributes_with_quotes(atts)
    atts.inject({}) do |quoted, (name, value)|
      if column = column_for_attribute(name)
        quoted[name] = quote(value, column)
      end
      quoted
    end
  end

  #MES- Create a user to correspond to an email address
  def self.create_user_from_email_address(email, source_user)
    # MGS- create a new user with the userid of the user's email address
    #MES- There's a race condition here- if multiple users come in with
    # similar names, we might hand a login to one of them, then think
    # that it's good to give another user the same login (since it might
    # not be stored yet.)  To get around this, we use a DB transaction.
    u = nil
    #MES- Does the source_user have the ability to make new users?
    # When MAX_USER_GENERATION is negative, there's no limit.
    if (MAX_USER_GENERATION < 0) || (source_user.generation_num < MAX_USER_GENERATION)
      User.transaction do
        login = unique_login_from_email(email)
        u = User.new(:login => login, :email => email)
        #MES- Copy the timezone from the "original" user
        u.time_zone = source_user.time_zone
        #KS- copy the zipcode from the "original" user as well
        u.zipcode = source_user.zipcode
        #MES- Ditto with geocode info
        u.lat_max, u.lat_min, u.long_max, u.long_min = source_user.lat_max, source_user.lat_min, source_user.long_max, source_user.long_min
        #MES- Increment the generation number
        u.generation_num = source_user.generation_num.nil? ? 1 : (source_user.generation_num + 1)
        #MES- Record the "invited by"
        u.invited_by = source_user.id
        u.save!
        #MES- Set the email to confirmed, since definitionally
        # this is the right email address for the user (the
        # email address is the ONLY think we know about the user!)
        email = u.emails[0]
        email.confirmed = Email::CONFIRMED
        email.save

        #KS- set the notification settings to the defaults for an unregistered user
        u.set_notifications_to_unregistered_defaults
        #MGS- always set the source user as a contact of the new user
        u.add_or_update_contact(source_user, { :friend_status => FRIEND_STATUS_CONTACT })
      end
    else
      #MES- This user can't create new users, log the attempt
      logger.error "GENERATION FAILURE: User #{source_user.id} attempted to invite #{email} to the system, but was not allowed due to a restriction on user generations (user generation is #{source_user.generation_num}, limit is #{MAX_USER_GENERATION})"
    end
    return u
  end

  #MES- Create a unique login string from an email address
  def self.unique_login_from_email(email)
    #MES- Ideally the login would be the username (e.g.
    # smedberg@gmail.com would be translated to smedberg.)
    # However, that name may not be available, so we have to
    # be a little careful.
    # We'd like to do something like:
    # select login from users where login like 'michaels%'
    # but that performs a full table scan.  Instead, we'll
    # look for unused logins one at a time.

    #MES- Get the user name (e.g. 'smedberg' from 'smedberg@gmail.com')
    #MES- Replace any disallowed characters with '_'
    email_username = email.gsub(/@.*/, '').gsub(/[^#{ALLOWED_LOGIN_CHARS}]/, '_')

    #MES- If the name is too short, extend it with '_'
    if MIN_LOGIN_LENGTH > email_username.length
      email_username = email_username + ('_' * (MIN_LOGIN_LENGTH - email_username.length))
    end

    #MES- Is the name taken?
    return email_username if !login_taken(email_username)

    #MES- We USED to make a provider based name, like smedberg_gmail.
    # That's a bit of a security hole, so we won't do that...

    #MES- The name is taken, append some numbers to try to make it unique
    1.upto(10) do | idx |
      name = "#{email_username}_#{idx}"
      return name if !login_taken(name)
    end

    #MES- OK, try some random numbers
    1.upto(50) do |idx |
      #MES- We add 11- 10 because we've already used the first 10 numbers, and 1
      # because the random numbers start at 0
      name = "#{email_username}_#{rand(9990) + 11}"
      return name if !login_taken(name)
    end

    #MES- Woah, we tried a LOT of names, and couldn't come up with a unique one.  Give up!
    raise "Error in User::unique_login_from_email, unable to create a unique login for email #{email}"
  end

  #MES- Returns a boolean indicating if a particular login string
  # is already owned by a Skobee user.
  def self.login_taken(login)
    #MES- Check if the indicated login exists
    ct = count(["login = ?", login])
    return (0 != ct)
  end

  def self.find_or_create_from_email(email_address, source_user)
    #MES- Find the user for the email address if they exist, or make a new one if they don't.
    # Returns the user, and a boolean indicating if the user was created (true) or found (false.)
    #MES- NOTE: create_user_from_email_address does locking, so we don't have to worry about race
    # conditions.
    usr = find_by_email(email_address)
    created = false
    if usr.nil?
      #MES- We couldn't find them, make a new user
      usr = create_user_from_email_address(email_address, source_user)
      created = true if !usr.nil?
    end

    return usr, created
  end

  #KS- get the timezone of the user based on their zipcode
  def self.get_timezone_from_zip(zip)
    sql = <<-END_OF_STRING
      SELECT
        offsets_timezones.time_zone
      FROM
        offsets_timezones, zipcodes
      WHERE
        zipcodes.zip = :zip AND
        zipcodes.timezone = offsets_timezones.offset AND
        zipcodes.dst = offsets_timezones.dst
    END_OF_STRING

    results = find_by_sql( [ sql, { :zip => zip } ] )

    if !results.nil? && results.length == 1
      return results[0].time_zone
    else
      logger.error("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
      logger.error("Could not find timezone for zipcode: #{zip}")
      logger.error("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
      return nil
    end
  end

  ####################################################################################
  ######  Items related to authentication and passwords
  ####################################################################################

  #KS: log them in by either email or login
  def self.authenticate(login, pass)
    #KS- hackity hack... this is just here because this gets called plenty often
    #we need to override the mysql query method...
    #TODO: remove this code as soon as we gather the information we need from the additional
    #logging in sk_mysql.rb
    MysqlLoader.load_our_mysql

    #MES- Original SQL looked like this:
    #    sql = <<-END_OF_STRING
    #      SELECT
    #        DISTINCT users.*
    #      FROM
    #        users, emails
    #      WHERE
    #        (users.login = :login OR emails.address = :login)
    #        AND emails.user_id = users.id
    #        AND emails.confirmed = 1
    #        AND users.deleted = 0
    #    END_OF_STRING
    # but this is VERY inefficient in MySQL, even with indexes
    # on users.login and emails.address.  It's not using the
    # indices.  To get around this, we'll do the "correct" query-
    # we'll check if the login looks like an email address.  If it
    # does, we'll do the lookup on the email table.  if not, we'll
    # do the lookup on the users table.  An alternative would be to
    # use a UNION.
    sql = nil
    if login.is_email?
      #MES- Construct SQL that checks the user email address
      sql = <<-END_OF_STRING
        SELECT
          DISTINCT users.*
        FROM
          users, emails
        WHERE
          emails.address = :login AND
          emails.confirmed = 1 AND
          emails.user_id = users.id AND
          users.deleted = 0
      END_OF_STRING
    else
      #MES- Construct SQL that looks up the user by login
      sql = <<-END_OF_STRING
        SELECT
          DISTINCT users.*
        FROM
          users,
          emails
        WHERE
          users.login = :login AND
          users.deleted = 0 AND
          users.id = emails.user_id AND
          emails.confirmed = 1
      END_OF_STRING
    end

    user_array = find_by_sql [sql, {:login => login}]

    #KS- if the size of user_array is > 1 we have database corruption
    if user_array.length > 1
      raise "Error in User.authenticate: found more than one user with the same login for login #{login}."
    end

    u = user_array[0]
    return nil if u.nil?
    return nil if u.salted_password != generate_salted_password(u.salt, pass)
    #MES- Record that we've done an authentication.
    u.update_attribute(:num_auths, u.num_auths + 1)
    u
  end

  def self.authenticate_by_token(id, token)
    # Allow logins for deleted accounts, but only via this method (and
    # not the regular authenticate call)
    u = find_first(["id = ? AND security_token = ?", id, token])
    return nil if u.nil? or u.token_expired?
    return nil if false == u.update_expiry
    #MES- Record that we've done an authentication.
    u.update_attribute(:num_auths, u.num_auths + 1)
    u
  end

  def token_expired?
    self.security_token and self.token_expiry and (Time.now > self.token_expiry)
  end

  def update_expiry(email = nil)
    write_attribute('token_expiry', [self.token_expiry, Time.at(Time.now.to_i + 600 * 1000)].min)
    write_attribute('authenticated_by_token', true)
    if email.nil?
      self.verified = 1
    else
      email.confirmed = Email::CONFIRMED
      email.save
    end
    update_without_callbacks
  end

  def destroy_security_token
    new_vals = { :token_expiry => nil, :security_token => nil }
    update_some new_vals
  end

  def generate_security_token(hours = nil)
    if not hours.nil? or self.security_token.nil? or self.token_expiry.nil? or
        (Time.now.to_i + token_lifetime / 2) >= self.token_expiry.to_i
      return new_security_token(hours)
    else
      return self.security_token
    end
  end

  def set_delete_after
    hours = UserSystem::CONFIG[:delayed_delete_days] * 24
    write_attribute('deleted', 1)
    write_attribute('delete_after', Time.at(Time.now.to_i + hours * 60 * 60))

    # Generate and return a token here, so that it expires at
    # the same time that the account deletion takes effect.
    return generate_security_token(hours)
  end

  def change_password(pass, confirm = nil)
    self.password = pass
    self.password_confirmation = confirm.nil? ? pass : confirm
    @new_password = true
  end

  #MES- Given the salt and the password, generate the salted password.
  def self.generate_salted_password(salt, password)
    #MES- This method exists to assure that all code generates salted
    # passwords in a uniform manner
    hashed(salt + hashed(password))
  end

  #MES- Update the salt in the DB and return the salt.  This effectively
  # invalidates any existing password!
  def update_salt
    write_attribute('salt', self.class.hashed("salt-#{Time.now}"))
    return self.salt
  end

  #MES- Does this user have this email address?
  def has_email?(address)
    #MES- Run through the emails, looking for one that's confirmed and matches the address
    return !(self.emails.detect { |em| Email:: CONFIRMED == em.confirmed && address == em.address }).nil?
  end


  protected

  attr_accessor :password, :password_confirmation

  def validate_password?
    @new_password
  end

  def self.hashed(str)
#MES- TODO: CHANGE THIS STRING!!!
    return Digest::SHA1.hexdigest("change-me--#{str}--")[0..(HASH_LENGTH - 1)]
  end

  after_save '@new_password = false'
  after_validation :crypt_password
  def crypt_password
    if @new_password
      self.salt = self.class.hashed("salt-#{Time.now}")
      self.salted_password = self.class.generate_salted_password(salt, @password)
    end
  end

  def new_security_token(hours = nil)
    write_attribute('security_token', self.class.hashed(self.salted_password + Time.now.to_i.to_s + rand.to_s))
    write_attribute('token_expiry', Time.at(Time.now.to_i + token_lifetime(hours)))
    update_without_callbacks
    return self.security_token
  end

  def token_lifetime(hours = nil)
    if hours.nil?
      UserSystem::CONFIG[:security_token_life_hours] * 60 * 60
    else
      hours * 60 * 60
    end
  end




###############################################################################
#MES- Items used by/as agents
###############################################################################

  def self.send_reminders(now = nil)
    info = User.find_users_and_plans_needing_reminders(now)
    num_sent = 0
    num_sent_to_registered_users = 0
    num_sent_to_unregistered_users = 0
    num_fuzzy_expiries = 0
    num_reminders = 0
    num_attempted = 0
    info.each do | row |
      usr = row[0]
      plans = row[1]
      num_attempted += plans.length
      begin
        plans.each { |plan|
          case
            when usr.registered? && plan.fuzzy?(usr.tz)
              UserNotify.deliver_fuzzy_expiry_reminder(usr, plan)
              num_sent_to_registered_users += 1
              num_fuzzy_expiries += 1

            when usr.registered? && !plan.fuzzy?(usr.tz)
              UserNotify.deliver_remind(usr, plan)
              log_error_if_reminder_later_than_expected(usr, plan)
              num_sent_to_registered_users += 1
              num_reminders += 1

            when !usr.registered? && plan.fuzzy?(usr.tz)
              UserNotify.deliver_unregistered_fuzzy_expiry_reminder(usr, plan)
              num_sent_to_unregistered_users += 1
              num_fuzzy_expiries += 1

            when !usr.registered? && !plan.fuzzy?(usr.tz)
              UserNotify.deliver_unregistered_remind(usr, plan)
              log_error_if_reminder_later_than_expected(usr, plan)
              num_sent_to_unregistered_users += 1
              num_reminders += 1
          end
          num_sent += 1
        }
      rescue Exception => exc
        #KS- log which email is causing us difficulties
        logger.error "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        logger.error "had a problem sending email to #{usr.email}"
        logger.error exc
        logger.error "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        log_for_agent "Failed to send reminder to #{usr.email} in User::send_reminders"
        log_for_agent exc
      end
      #KS- set notified if we didn't raise an exception
      usr.record_notified(plans)
    end

    log_for_agent "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
    log_for_agent "Successfully sent #{num_sent} of #{num_attempted} reminders / fuzzy expiry notifications in User::send_reminders"
    log_for_agent "------------------------------------------------------------------"
    log_for_agent "#{num_sent_to_registered_users} sent to registered users"
    log_for_agent "#{num_sent_to_unregistered_users} sent to unregistered users"
    log_for_agent "#{num_fuzzy_expiries} fuzzy expiry notices"
    log_for_agent "#{num_reminders} reminders"
    log_for_agent "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

    return num_sent
  end

  #KS- if this function is called (it should only be called right after sending
  #a reminder) more than 30 minutes after the expected send time (based on the user's
  #reminder minutes user att and the plan time), log an error in the agent log
  def self.log_error_if_reminder_later_than_expected(user, plan)
    reminder_hours = user.get_att_value(UserAttribute::ATT_REMINDER_HOURS)

    expected_reminder_time = plan.start - reminder_hours.hours
    latest_acceptable_reminder_time = expected_reminder_time + 30.minutes
    now = Time.now

    if now > latest_acceptable_reminder_time
      minutes_between_now_and_correct = (now - expected_reminder_time).minutes
      log_for_agent "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
      log_for_agent "out of date reminder sent to #{user.login} for plan #{plan.id} #{plan.name.nil? ? '' : plan.name}"
      log_for_agent "off by #{minutes_between_now_and_correct} minutes"
      log_for_agent "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    end
  end

  def self.update_contacts
    #MES- Contacts can be added manually in various ways (e.g. when a user indicates
    # that another user is a friend, that is stored as a contact.)
    # However, contacts can also be added automatically.  For example, when
    # a user shares a plan with another user (i.e. they are both accept invitations
    # to a common plan), both users should treat each other as contacts.
    #
    #This function is intended to update these automatic relationships- to make sure
    # that users have the proper contacts.

    #MES- TODO: This will potentially make cached contacts lists invalid- is there
    # a way to invalidate them?

    log_for_agent "In User::update_contacts, attempting to update contacts"

    #MES- Add missing contacts via SQL
    insert_missing_contacts_sql = <<-END_OF_STRING
      INSERT INTO user_contacts (user_id, contact_id, connections, contact_created_at)
      SELECT
        c1.user_id, c2.user_id, count(*), UTC_TIMESTAMP()
      FROM
        #{Planner.table_name} AS c1,
        #{Planner.table_name} AS c2,
        planners_plans AS ce1,
        planners_plans AS ce2
      WHERE
        c1.id = ce1.planner_id AND
        ce1.plan_id = ce2.plan_id AND
        ce1.cal_pln_status = ? AND
        ce2.cal_pln_status = ? AND
        c2.id = ce2.planner_id AND
        c1.user_id != c2.user_id AND
        NOT EXISTS (
          SELECT *
          FROM
            user_contacts
          WHERE
            user_contacts.user_id = c1.user_id AND
            user_contacts.contact_id = c2.user_id
        )
      GROUP BY
        c1.user_id, c2.user_id
    END_OF_STRING

    perform_insert_sql( [ insert_missing_contacts_sql, Plan::STATUS_ACCEPTED, Plan::STATUS_ACCEPTED ], "Adding missing contacts")

    #MES- Update the connections counts via SQL

    #MES- NOTE:  We would LIKE to update the connection count
    # with a single correlated subquery, like this:


#    update_contacts_counts_sql = <<-END_OF_STRING
#      UPDATE user_contacts
#      SET connections = (
#       SELECT count(*)
#       FROM
#         planners AS c1,
#         planners AS c2,
#         planners_plans AS ce1,
#         planners_plans AS ce2
#       WHERE
#         c1.id = ce1.planner_id AND
#         ce1.plan_id = ce2.plan_id AND
#         ce1.cal_pln_status IN (?) AND
#         ce2.cal_pln_status IN (?) AND
#         c2.id = ce2.planner_id AND
#         c1.user_id = user_contacts.user_id AND
#         c2.user_id = user_contacts.contact_id
#      )
#    END_OF_STRING

    #MES- But this doesn't seem to work on some MySQL databases.  It's not clear why;
    # I tried to reproduce the problem with simpler SQL and with simpler table structures
    # but they did not reproduce the problem. In any case, if we use a temp table, it seems
    # more stable.

    User.transaction do

      #MES- Copy the relevant data into a temp table
      create_temp_data_sql = <<-END_OF_STRING
        CREATE TEMPORARY TABLE temp_upd_ctcts
          SELECT c1.user_id AS user_id, c2.user_id AS contact_id, count(*) AS ct
          FROM
            planners AS c1,
            planners AS c2,
            planners_plans AS ce1,
            planners_plans AS ce2
          WHERE
            c1.id = ce1.planner_id AND
            ce1.plan_id = ce2.plan_id AND
            ce1.cal_pln_status = ? AND
            ce2.cal_pln_status = ? AND
            c2.id = ce2.planner_id
          GROUP BY
           c1.user_id, c2.user_id
      END_OF_STRING

      perform_insert_sql( [create_temp_data_sql, Plan::STATUS_ACCEPTED, Plan::STATUS_ACCEPTED], "Creating temp table for contact counts")

      #MES- Update the main table based on the data in the temp table
      update_user_contacts_sql = <<-END_OF_STRING
        UPDATE user_contacts
          SET connections =
          (
            SELECT ct
            FROM
              temp_upd_ctcts
            WHERE
              temp_upd_ctcts.user_id = user_contacts.user_id AND
              temp_upd_ctcts.contact_id = user_contacts.contact_id
           );
      END_OF_STRING

      perform_update_sql(update_user_contacts_sql, "Updating contact counts")

      #MES- The previous update might have set some records to NULL, correct them here
      update_user_contacts_null_sql = <<-END_OF_STRING
         UPDATE user_contacts
          SET connections = 0
          WHERE connections IS NULL;
      END_OF_STRING

      perform_update_sql(update_user_contacts_null_sql, "Updating contact counts for NULL counts")

      #MES- Get rid of the temp table, we're done
      drop_temp_table_sql = <<-END_OF_STRING
         DROP TEMPORARY TABLE temp_upd_ctcts;
      END_OF_STRING

      perform_update_sql(drop_temp_table_sql, "Dropping temp table used to update contact counts")
    end
    log_for_agent "Successfully updated contacts in User::update_contacts"
  end

  def self.cleanup_sessions
    #MES- cleanup_sessions is a frequently run agent, so we don't do much logging-
    # we don't want our logs to get huge.
    #MES- Delete any defunct sessions
    delete_sessions_sql = <<-END_OF_STRING
      DELETE FROM sessions
      WHERE TIME_TO_SEC(TIMEDIFF(UTC_TIMESTAMP(), updated_at)) > ?
    END_OF_STRING

    perform_delete_sql([delete_sessions_sql, SESSION_LIFETIME_SECS], "Cleaning up sessions")
  end

  def self.create_users_from_file(filename, master_user = create_master_user)
    #MES- Create users from the file.  This is used to seed the system
    # for known users in a relatively simple manner.
    #
    # The file contains the email address of each user, one email per line.
    # After completion, the users are created but NOT registered.
    # This function puts the register URLs for each user to STDOUT, like
    # email[TAB]register URL
    create_users_from_file_helper(filename, master_user) do | usr, email |
      url = "#{UserSystem::CONFIG[:app_url].to_s}users/register/#{usr.id}"
      $stdout.puts "#{email}\t#{url}"
    end
  end

  def self.create_and_email_users_from_file(filename, master_user = create_master_user)
    #MES- This is functionally very similar to create_users_from_file.  However,
    # instead of reporting the registration URL to the user on STDOUT, the registration
    # URL will be sent to the user in a notification email.
    create_users_from_file_helper(filename, master_user) do | usr, email |
      url = "#{UserSystem::CONFIG[:app_url].to_s}users/register/#{usr.id}"
      UserNotify.deliver_notify_of_registration(usr, url)
      $stdout.puts "#{email}: created user and delivered email"
    end
  end

  def self.create_users_from_file_helper(filename, master_user)
    #MES- Open the file, read emails from each line, try to make
    # a user for each email.
    open(filename, 'r') do | file |
      file.each do | line |
        email = line.chomp
        if find_by_email(email).nil?
          usr = create_user_from_email_address(email, master_user)
          if !usr.nil?
            yield usr, email
          else
            $stderr.puts "ERROR: Failed to create user for email address #{email}"
          end
        else
          $stderr.puts "ERROR: User with email #{email} already exists"
        end
      end
    end
  end

  def self.create_master_user(time_zone = nil, lat = nil, long = nil)
    #MES- Create a user that can be the "master" for creating other users-
    # to be passed into create_user_from_email_address.

    #MES- Did we get a timezone?
    time_zone = DEFAULT_TIME_ZONE

    #MES- Did we get a lat and long?
    if lat.nil? || long.nil?
      lat = DEFAULT_LAT
      long = DEFAULT_LONG
    end

    center = GeocodeCacheEntry.new(:lat => lat, :long => long)
    bounding_box = GeocodeCacheEntry.get_bounding_box_array(center, DEFAULT_MAX_PROX_SEARCH_MILES)

    user = User.new(:id => -1, :time_zone => time_zone, :lat => lat, :long => long, :lat_max => bounding_box[0], :lat_min => bounding_box[1], :long_max => bounding_box[2], :long_min => bounding_box[3], :generation_num => -1)
    
    #KS- default new users' zipcodes to international
    user.zipcode = INTL_USER_ZIPCODE_STR
    
    return user
  end

###############################################################################
##### Master agents- these call the other agents
###############################################################################

  def self.frequent_tasks
    #MES- Run all tasks that should be run frequently (i.e. every few minutes.)
    # This job merely wraps other jobs, making them easier to schedule.
    User.run_agents [
      'User.send_reminders',
      'User.cleanup_sessions']
  end

  def self.nightly_tasks
    #MES- Run all tasks that should be run nightly.
    # This job merely wraps other jobs, making them easier to schedule.
    User.run_agents [
      'User.update_contacts',
      'User.update_metro_info',
      'Place.perform_geocoding',
      'Place.update_usage_stats',
      'Place.update_popularity_stats']
  end

  def self.run_agents(names)
    names.each do | name |
      begin
        eval name
      rescue Exception => exc
        log_for_agent "Exception raised by agent #{name}:"
        log_for_agent exc, false
      end
    end
  end


  ####################################################################################
  ####  Validation functions and helpers
  ####################################################################################

  #KS- validates the emails
  # this is here instead of in the email model for the same reason mark
  # cites above the user_atts validation (namely, doing it in the email
  # model only makes one entry into the parent (user) errors collection.
  validates_each :emails do |record, attr, values|
    values.each do |email|
      if !email.validate_format
        email.errors.each do |key, error|
          record.errors.add "Email", error
        end
      end
      #MES- Suppress further validation of the emails.  We already know if
      # they're bad, and we don't want an error in the errors collection
      # that looks like ['Emails', 'is invalid'].
      email.suppress_validation = true
    end
  end

  #MGS- Validate the user attributes
  # This is in the user model instead of the user_attribute model
  # because, validating in the user_attribute model only makes one
  # entry into the parent (user) errors collection.
  # Not finding a workaround for that, the validation is here...
  #MGS- some of this was moved out of the user controller
  validates_each :user_atts do |record, attr, values|
    values.each do |attr|
      case attr.att_id
        when UserAttribute::ATT_BIRTH_YEAR
          User.validate_birth_year(attr.att_value, record)
        when UserAttribute::ATT_ZIP
          User.validate_zip(attr.att_value, record)
      end
    end
  end

  #KS- make sure that the screen name and first/last names are alphanumeric.
  #first/last names can also contain spaces and dashes
  validates_format_of :login, :with => /^[#{ALLOWED_LOGIN_CHARS}]+$/, :message => "contains disallowed characters."
  validates_format_of :real_name, :with => /^[a-zA-Z0-9\-_'."\s]*$/, :message => "contains disallowed characters."

  validates_presence_of :login
  validates_length_of :login, :within => MIN_LOGIN_LENGTH..MAX_LOGIN_LENGTH
  #MES- Do NOT check for unique login if we're registering a user- i.e. we're connecting a client
  # to an existing user object.
  validates_uniqueness_of :login, :if => Proc.new { | user | !user.suppress_uniqueness_validation }, :message => "is already in use."

  validates_presence_of :password, :if => :validate_password?
  validates_confirmation_of :password, :if => :validate_password?
  validates_length_of :password, { :minimum => 5, :if => :validate_password? }
  validates_length_of :password, { :maximum => 40, :if => :validate_password? }

  def self.validate_zip(zip, add_errors_to)
    #MES- If the zip code is the international dummy value, don't map to a timezone
    if INTL_USER_ZIPCODE_STR != zip
      #KS- set the timezone based on the zipcode; error if zipcode is not recognized
      if !zip.match(/^\d{5}$/)
        add_errors_to.errors.add(:zipcode, 'is invalid. We use your Zip code to help you find local places. Your location is kept private and will never be shared. Please enter a valid 5 digit US Zip code.')
      elsif User.get_timezone_from_zip(zip).nil?
        add_errors_to.errors.add(:zipcode, 'you entered could not be found. You must enter a valid 5-digit US zip code (for example: \'94105\').')
      end
    end
  end

  def self.validate_birth_year(value, add_errors_to)
    #KS- validate the birth year
    if !value.blank?
      birth_year_diff = Time.now.year - value.to_i

      if birth_year_diff < 10
        add_errors_to.errors.add "Birthday", "seems wrong- If you're really that young you probably can't read this."
      elsif birth_year_diff > 120
        add_errors_to.errors.add "Birthday", "seems wrong- you can't be THAT old!"
      end
    end
  end


  #MES- Override validate for some specific cases
  def validate
    #MES- The zip code is required
    if user_atts.select{ |att| att.att_id == UserAttribute::ATT_ZIP }.length == 0
      errors.add "Zip code", "is required."
    else
     #MES- The timezone is required, but it's typically derived from the zip code, so
     #  don't warn about the time zone if we're already warning about the zip code
     if !time_zone.blank?
        #MES- Validate the timezone by trying to open the relevant TZInfo object
        begin
          tz = TZInfo::Timezone.get(time_zone)
        rescue Exception
          errors.add "Timezone", "'#{time_zone}' is not recognized."
        end
      else
          errors.add "Timezone", "is required."
      end
    end
    
  end

  ########################################################################
  ###### MES- Private helper functions
  ########################################################################
  private



  def find_att(att_id, group_id = nil)
    #MES- Return the attribute corresponding to the ID if it exists,
    # or nil if not
    if group_id.nil?
      att_to_return = user_atts.detect { | att | "#{att.att_id}" == "#{att_id}" }
    else
      att_to_return = user_atts.detect { | att | att.att_id == att_id && att.group_id.to_i == group_id.to_i }
    end

    return att_to_return
  end
end
