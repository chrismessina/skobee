class EmailId < ActiveRecord::Base
  belongs_to :plan
  PLAN_PREFIX = 'a'
  
  #MES- Returns an email address that can be used as the "from"
  # for emails sent by Skobee.  These addresses include the plan id
  # in a way that can be retrieved later.
  def self.email_address_for_plan(plan)
    if plan.is_a? Plan
      plan = plan.id
    end
    
    #MES- Were we given a plan?
    if !plan.nil?
      #MES- Sandwich in the plan ID behind the email address.  Separate with a '+'.
      return "#{UserSystem::CONFIG[:email_from_user]}+#{PLAN_PREFIX}#{plan.to_s}#{UserSystem::CONFIG[:email_from_server]}"
    else
      #MES- No plan, just return the email
      return UserSystem::CONFIG[:email_from_user] + UserSystem::CONFIG[:email_from_server]
    end
  end
  
  #MES- Reverse the action of email_address_for_plan- given an email, try to 
  # get the plan ID from it.  Returns nil of no plan id available.
  def self.plan_id_from_email(email)
    #MES- Look through the recipient email addreses
    email.to.each do | email_to |
      #MES- Is this an email address we care about?  Is it to Skobee
      # and does it have a prefix we can parse out?
      m = email_to.match(/^#{UserSystem::CONFIG[:email_from_user]}\+#{PLAN_PREFIX}([^@]*)#{UserSystem::CONFIG[:email_from_server]}$/)
      if !m.nil?
        return m[1].to_i
      end
    end
    
    #MES- Didn't find anything- return nil.
    return nil
  end
  
  #MES- Take an email subject string.  Return a canonicalized string, which removes
  # leading "RE: " and "FW: " strings, etc.  If nil is passed in, nil is returned.
  def self.canonicalize_subject(subject)
    return nil if subject.nil?
    
    #MES- Strip off leading RE: and FW: strings (case insensitive)
    #MES- Match any number of RE: or FW:, followed by any amount of white space, and
    # ignore leading white space.
    m = subject.match(/^\s*(([Rr][Ee]|[Ff][Ww]):\s*)*(.*)$/)
    if !m.nil?
      subject = m[3]
    end
    
    return subject
  end
  
  #MES- Turn an address like x+y@z.com into x@z.com
  def self.remove_plus_from_email_address(email)
    #MES- Some email systems allow users to use a "+" in the address
    #  to allow a single account to essentially have multiple addresses.
    #  We wanna trim these out.    
    m = email.match(/([^+]*)(\+[^@]*)(@.*)/)
    if !m.nil?
      email = m[1] + m[3]
    end
    
    return email
  end
end
