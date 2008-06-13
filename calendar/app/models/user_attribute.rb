#MES- A UserAttribute is an (extensible) fact about
# a user, such as work address or AIM screen name.
class UserAttribute < ActiveRecord::Base
  set_table_name 'user_atts'

  #KS- privacy setting options for real name (special case)
  REAL_NAME_PRIVACY_SETTINGS = [ SkobeeConstants::PRIVACY_LEVEL_PUBLIC, SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE ].freeze


  #KS- invite notification options
  INVITE_NOTIFICATION_ALWAYS = 0
  INVITE_NOTIFICATION_NEVER = 1

  #KS- plan modified notification options
  PLAN_MODIFIED_ALWAYS = 0
  PLAN_MODIFIED_NEVER = 1

  #KS- confirmed plan reminder options
  CONFIRMED_PLAN_REMINDER_ALWAYS = 0
  CONFIRMED_PLAN_REMINDER_NEVER = 1

  #KS- added as a friend notification options
  ATT_ADDED_AS_FRIEND_NOTIFICATION_ALWAYS = 0
  ATT_ADDED_AS_FRIEND_NOTIFICATION_NEVER = 1

  #KS- used for various user_atts that store booleans
  TRUE_USER_ATT_VALUE = 1
  FALSE_USER_ATT_VALUE = 0


  ATT_ZIP = 2
  ATT_MOBILE_PHONE = 3
  ATT_REMIND_BY_EMAIL = 10
  ATT_REMIND_BY_SMS = 11
  ATT_INVITE_NOTIFICATION_OPTION = 12
  ATT_PLAN_MODIFIED_NOTIFICATION_OPTION = 13
  ATT_CONFIRMED_PLAN_REMINDER_OPTION = 14
  ATT_REMINDER_HOURS = 15
  ATT_ADDED_AS_FRIEND_NOTIFICATION_OPTION = 16
  ATT_SECURITY = 17
  ATT_ALLOW_PLAN_CREATION_VIA_EMAIL = 18
  ATT_RELATIONSHIP_STATUS = 19
  ATT_GENDER = 20
  ATT_BIRTH_MONTH = 21
  ATT_BIRTH_DAY = 22
  ATT_BIRTH_YEAR = 23
  ATT_PLAN_COMMENTED_NOTIFICATION_OPTION = 24
  ATT_USER_COMMENTED_NOTIFICATION_OPTION = 25
  ATT_FLICKR_ID = 26

  #KS- group attributes
  ATT_ZIP_SECURITY_GROUP = 2
  ATT_MOBILE_PHONE_SECURITY_GROUP = 3
  ATT_BIRTHDAY_AGE_SECURITY_GROUP = 4
  ATT_GENDER_SECURITY_GROUP = 8
  ATT_RELATIONSHIP_STATUS_SECURITY_GROUP = 9
  ATT_DESCRIPTION_SECURITY_GROUP = 10
  ATT_REAL_NAME_SECURITY_GROUP = 11
  ATT_EMAIL_SECURITY_GROUP = 12

  #KS- group mappings
  GROUP_MAPPINGS = {
    ATT_ZIP => ATT_ZIP_SECURITY_GROUP,
    ATT_MOBILE_PHONE => ATT_MOBILE_PHONE_SECURITY_GROUP,
    ATT_BIRTH_MONTH => ATT_BIRTHDAY_AGE_SECURITY_GROUP,
    ATT_BIRTH_DAY => ATT_BIRTHDAY_AGE_SECURITY_GROUP,
    ATT_BIRTH_YEAR => ATT_BIRTHDAY_AGE_SECURITY_GROUP,
    ATT_GENDER => ATT_GENDER_SECURITY_GROUP,
    ATT_RELATIONSHIP_STATUS => ATT_RELATIONSHIP_STATUS_SECURITY_GROUP
  }

  #KS- map of the attributes that should be returned as integer types. note that
  #they are stored as strings in the database just like all the other atts, but
  #on returning them we should convert them to ints.
  #TODO: when we put atts into the db maybe we should do some sort of type
  #checking based on this map?
  ATT_TYPES = {
    ATT_INVITE_NOTIFICATION_OPTION => Integer,
    ATT_PLAN_MODIFIED_NOTIFICATION_OPTION => Integer,
    ATT_PLAN_COMMENTED_NOTIFICATION_OPTION => Integer,
    ATT_USER_COMMENTED_NOTIFICATION_OPTION => Integer,
    ATT_CONFIRMED_PLAN_REMINDER_OPTION => Integer,
    ATT_REMINDER_HOURS => Integer,
    ATT_ADDED_AS_FRIEND_NOTIFICATION_OPTION => Integer,
    ATT_SECURITY => Integer,
    ATT_REMIND_BY_EMAIL => Integer,
    ATT_ALLOW_PLAN_CREATION_VIA_EMAIL => Integer
  }.freeze

  #KS- display for all the birth data
  BIRTH_DAYS = [
    [ nil, 'DD' ],
    [ 1, '01' ],
    [ 2, '02' ],
    [ 3, '03' ],
    [ 4, '04' ],
    [ 5, '05' ],
    [ 6, '06' ],
    [ 7, '07' ],
    [ 8, '08' ],
    [ 9, '09' ],
    [ 10, '10' ],
    [ 11, '11' ],
    [ 12, '12' ],
    [ 13, '13' ],
    [ 14, '14' ],
    [ 15, '15' ],
    [ 16, '16' ],
    [ 17, '17' ],
    [ 18, '18' ],
    [ 19, '19' ],
    [ 20, '20' ],
    [ 21, '21' ],
    [ 22, '22' ],
    [ 23, '23' ],
    [ 24, '24' ],
    [ 25, '25' ],
    [ 26, '26' ],
    [ 27, '27' ],
    [ 28, '28' ],
    [ 29, '29' ],
    [ 30, '30' ],
    [ 31, '31' ]
  ]
  BIRTH_MONTHS = [
    [ nil, 'MM' ],
    [ 1, '01' ],
    [ 2, '02' ],
    [ 3, '03' ],
    [ 4, '04' ],
    [ 5, '05' ],
    [ 6, '06' ],
    [ 7, '07' ],
    [ 8, '08' ],
    [ 9, '09' ],
    [ 10, '10' ],
    [ 11, '11' ],
    [ 12, '12' ]
  ]

  #KS- different relationship statuses and their display values
  RELATIONSHIP_TYPE_UNKNOWN = 0
  RELATIONSHIP_TYPE_SINGLE = 1
  RELATIONSHIP_TYPE_TAKEN = 2
  RELATIONSHIP_STATUSES = [
    [ RELATIONSHIP_TYPE_UNKNOWN, "Rather not say" ],
    [ RELATIONSHIP_TYPE_SINGLE, "single" ],
    [ RELATIONSHIP_TYPE_TAKEN, "taken"]
  ]

  #KS- different genders
  GENDER_UNKNOWN = 0
  GENDER_MALE = 1
  GENDER_FEMALE = 2
  GENDER_TYPES = [
    [ GENDER_UNKNOWN, "Rather not say" ],
    [ GENDER_MALE, "male" ],
    [ GENDER_FEMALE, "female" ]
  ]

  #KS- default settings for notifications
  DEFAULT_REMIND_BY_EMAIL = true
  DEFAULT_INVITE_NOTIFICATION = INVITE_NOTIFICATION_ALWAYS
  DEFAULT_PLAN_MODIFIED_NOTIFICATION = PLAN_MODIFIED_ALWAYS
  DEFAULT_PLAN_COMMENTED_NOTIFICATION = FALSE_USER_ATT_VALUE
  DEFAULT_USER_COMMENTED_NOTIFICATION = TRUE_USER_ATT_VALUE
  DEFAULT_CONFIRMED_PLAN_REMINDER = CONFIRMED_PLAN_REMINDER_ALWAYS
  DEFAULT_REMINDER_HOURS = 6
  DEFAULT_ADDED_AS_FRIEND_NOTIFICATION = ATT_ADDED_AS_FRIEND_NOTIFICATION_ALWAYS

  #KS- default settings for privacy
  DEFAULT_PLANNER_VISIBILITY_TYPE = SkobeeConstants::PRIVACY_LEVEL_PUBLIC
  DEFAULT_REAL_NAME_SECURITY = SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE
  DEFAULT_EMAIL_SECURITY = SkobeeConstants::PRIVACY_LEVEL_FRIENDS
  DEFAULT_BIRTHDAY_AGE_SECURITY = SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE
  DEFAULT_RELATIONSHIP_STATUS_SECURITY = SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE
  DEFAULT_DESCRIPTION_SECURITY = SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE
  DEFAULT_GENDER_SECURITY = SkobeeConstants::PRIVACY_LEVEL_ALL_SKOBEE

  def validate_on_update
    case att_id
      when UserAttribute::ATT_BIRTH_YEAR
        User.validate_birth_year(att_value, self)
      when UserAttribute::ATT_ZIP
        User.validate_zip(att_value, self)
    end
  end
end