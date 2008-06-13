#MES- A class to hold constants that are global to Skobee
class SkobeeConstants
  
  #KS- privacy settings for various aspects of the user profile
  #IMPORTANT NOTE: more restrictive settings must always have a larger constant
  #number assigned to them. i am making the (perhaps invalid) assumption that
  #security groups will always be subsets of the next less most restrictive one
  #sorta like matrioshka dolls
  PRIVACY_LEVEL_PUBLIC = 0          #KS- anyone can see it, including non logged in users
  PRIVACY_LEVEL_ALL_SKOBEE = 1      #KS- only logged in skobee users can see it
#KS- commenting this out for now because we aren't gonna do it in v1
#TODO: put contacts-based security in
#  PRIVACY_LEVEL_CONTACTS = 2        #KS- only contacts can see it
  PRIVACY_LEVEL_FRIENDS = 3         #KS- only friends can see it
  PRIVACY_LEVEL_PRIVATE = 4         #KS- only the owner can see it
  PRIVACY_LEVEL_INVALID = PRIVACY_LEVEL_PRIVATE + 1 #MES- A dummy value, one larger than any allowed value
  
  PRIVACY_LEVELS = [
    PRIVACY_LEVEL_PUBLIC,
    PRIVACY_LEVEL_ALL_SKOBEE,
#KS- commenting this out for now because we aren't gonna do it in v1
#TODO: put contacts-based security in
#    PRIVACY_LEVEL_CONTACTS,
    PRIVACY_LEVEL_FRIENDS,
    PRIVACY_LEVEL_PRIVATE ].freeze
    

  PRIVACY_SETTINGS_NAMES = {
    PRIVACY_LEVEL_PUBLIC => "anyone",
    PRIVACY_LEVEL_ALL_SKOBEE => "all skobee members",
#KS- commenting this out for now because we aren't gonna do it in v1
#TODO: put contacts-based security in
#    PRIVACY_LEVEL_CONTACTS => "any of my contacts",
    PRIVACY_LEVEL_FRIENDS => "any of my friends",
    PRIVACY_LEVEL_PRIVATE => "only me" }.freeze
end