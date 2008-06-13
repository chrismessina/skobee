class Email < ActiveRecord::Base
  belongs_to :user, :class_name => 'User'

  #KS- constants for confirmed/unconfirmed email addresses
  CONFIRMED = 1
  UNCONFIRMED = 0
  
  #KS- constants for primary/not primary email addresses
  PRIMARY = 1
  NOT_PRIMARY = 0
  
  #MES- Set this variable if you don't want emails to validate themselves
  attr_accessor :suppress_validation

  def validate
    if !self.suppress_validation
      validate_format
    end
  end
  
  def validate_format
    if !address.is_email?
      errors.add_to_base 'address is invalid.'
      return false
    else
      return true
    end
  end

  def validate_unique_confirmed
    if exists_and_confirmed?
      errors.add_to_base "address #{address} is already in use. Please try again or use 'forgot my password' to recover your account."
      return false
    end
  end
  
  def exists_and_confirmed?
    conditions_string = 'address = :address AND confirmed = 1'
    conditions_hash = { :address => address }
    if !user.nil? && !user.id.nil?
      conditions_string += ' AND user_id != :user_id'
      conditions_hash[:user_id] = user.id
    end

    return !Email.find(:first, :conditions => [conditions_string, conditions_hash]).nil?
  end

end
