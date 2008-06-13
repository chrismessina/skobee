class String
  #KS- format an email string for display on skobee (makes it a little more annoying
  #for email scrapers to grab)
  def email_formatted_for_display
    return self.gsub('@', ' [at] ').gsub('.', ' [dot] ')
  end

  #MGS- return true if string format is a valid email address
  def is_email?
    #MGS- email pattern to match
    #MGS- changing beginning ^ and ending $ to \A and \z....this fixes a bug where
    # line breaks in a string were still passing as valid emails...as long as what
    # was entered before the first line break was a valid email.  $ only matches
    # to the end of the line.
    email = Regexp.new(/\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i)
    self =~ email
  end

  def split_delimited_emails()
    #MGS- take a string and returns an array of emails from it
    # currently we support comma and semi-colon as delimiters between emails
    #MGS- TODO- maybe we add email validation here as well?  Leaving validation in the
    # controllers for now because it's done differently in different spots.
   	#	MES- In addition, we support "fully specified" email addresses, like
   	#	"Michael Smedberg" <smedberg@gmail.com>
    
    #MES- Split by the allowed delimiters
    emails = self.split(/\s*[\,\;]\s*/)
    #MGS- remove any whitespace around the emails
    emails.collect!{|email| email.strip}
    	
   	#MES- Replace any "fully specified" sequence (like '"Michael Smedberg" <smedberg@gmail.com>'
   	#	with the email portion (e.g. 'smedberg@gmail.com')
   	emails.collect! do | email |
   		res = email
   		#MES- Does it look like 'some string <some other string>'?
   		m = email.match(/[^<]*<([^>]+)>/)
   		if !m.nil?
   			#MES- It does, use the 'some other string' portion
   			res = m[1]
   		end
   		res
   	end
    	
    #MGS- remove any blank entries
    return emails.delete_if{|email| email.empty? }
    	
  end
  
  #MES- Escape double quotes with the '\' character, and escape the '\' character as well
  def escape_double_quotes
    return self.gsub('"', '\"')
  end
  
  #MES- Converts the string to a Time, in the same manner that Rails does for
  # datetimes from the DB
  def to_time
    #MES- From activerecord-1.13.2\lib\active_record\connection_adapters\abstract\schema_definitions.rb
    # Function was called string_to_time
    time_array = ParseDate.parsedate(self)[0..5]
    # treat 0000-00-00 00:00:00 as nil
    #MES- Next line WAS the following, but we don't have access to Base here
    #Time.send(Base.default_timezone, *time_array) rescue nil
    Time.utc(*time_array) rescue nil
  end

  #MES- Some helper functions grabbed from http://www.bigbold.com/snippets/posts/show/557
  def titlecase()
    ignore_list = %w{of etc and by the for on is at to but nor or a via}
    capitalize_all_ex(ignore_list)
  end

  def titlecase!()
    ignore_list = %w{of etc and by the for on is at to but nor or a via}
    capitalize_all_ex!(ignore_list)
  end

  def capitalize_all(force_downcase = true)
    ignore_list = %w{}
    capitalize_all_ex(ignore_list, force_downcase)
  end

  def capitalize_all!(force_downcase = true)
    ignore_list = %w{}
    capitalize_all_ex!(ignore_list, force_downcase)
  end

  def capitalize_all_ex(ignore_list, force_downcase = true)
    # if force_downcase is true then the
    # string is, um, downcased first :-)
    if force_downcase
      self.downcase.gsub(/[\w\']+/){ |w|
        ignore_list.include?(w) ? w : w.capitalize
      }
    else
      self.gsub(/[\w\']+/){ |w|
        ignore_list.include?(w) ? w : w.capitalize
      }
    end
  end

  def capitalize_all_ex!(ignore_list, force_downcase = true)
    if force_downcase
      self.replace(self.downcase.gsub(/[\w\']+/){ |w|
        ignore_list.include?(w) ? w : w.capitalize
      })
    else
      self.replace(self.gsub(/[\w\']+/){ |w|
        ignore_list.include?(w) ? w : w.capitalize
      })
    end
  end
  
  #MES- Does this string contain an integer?  I.e. does it ONLY contain digits?
  def contains_int?
  	return false if self.empty?
  	return self.match(/^[0-9]+$/)
  end
end