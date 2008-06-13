#MES- Modifies the class in C:\ruby\lib\ruby\gems\1.8\gems\activerecord-1.14.2\lib\active_record\base.rb
module ActiveRecord
  class Base
    #MES- This kinda bites.  The sanitize_sql method
    # of ActiveRecord::Base is protected, so instances
    # of AR can't call it directly.  I made these wrappers
    # to expose the desired functionality to instances.
  
    def perform_select_all_sql(sql, desc = nil)
      self.class.perform_type_of_sql(:select_all, sql, desc)
    end
  
    def perform_insert_sql(sql, desc = nil)
      self.class.perform_type_of_sql(:insert, sql, desc)
    end
  
    def perform_update_sql(sql, desc = nil)
      self.class.perform_type_of_sql(:update, sql, desc)
    end
  
    def perform_delete_sql(sql, desc = nil)
      self.class.perform_type_of_sql(:delete, sql, desc)
    end
  
    def self.perform_select_all_sql(sql, desc = nil)
      perform_type_of_sql(:select_all, sql, desc)
    end
  
    def self.perform_insert_sql(sql, desc = nil)
      perform_type_of_sql(:insert, sql, desc)
    end
  
    def self.perform_update_sql(sql, desc = nil)
      perform_type_of_sql(:update, sql, desc)
    end
  
    def self.perform_delete_sql(sql, desc = nil)
      perform_type_of_sql(:delete, sql, desc)
    end
  
    def self.perform_type_of_sql(type, sql, desc = nil)
      if desc.nil?
        connection().send(type, sanitize_sql(sql))
      else
        connection().send(type, sanitize_sql(sql), desc)
      end
    end
  
    #MES- A helper that takes in an item or an array, and returns the appropriate
    # SQL convention (i.e. returns 'IN (?)' for an array, or '= ?' for a non-array.)
    def self.sql_frag_for_equal_or_in(arg)
      if arg.kind_of? Array
        return 'IN (?)'
      else
        return '= ?'
      end
    end
  
    #MES- A helper that returns the cols for the table for the model, separated by ', '.
    # You can pass in an optional prefix.  If it's not nil or blank, this function will
    # separate the prefix from the column name with a '.'
    def self.cols_for_select(prefix = nil)
      #MES- Nil prefix is blank
      if prefix.nil? || prefix.empty?
        self.column_names.join(', ')
      else
        self.column_names.map { | col | "#{prefix}.#{col}" }.join(', ')
      end
  
    end
  
    #MES- Some helpers for marshalling and unmarshalling data
    def marshal(data)   Base64.encode64(Marshal.dump(data)) if data end
    def unmarshal(data) Marshal.load(Base64.decode64(data)) if data end
  
    #MES- How an agent should do logging
    def self.log_for_agent(msg, include_date = true)
      #MES- We'll print the string to stdout (which the script running the agent
      # should save for us.)  We'll add some more info, like the current time.
      #MES- This date format is the same as used by default by lighttp.  The idea
      # is that our logs will be easier to read if we use a uniform date format.
      msg = include_date ? "#{Time.now.strftime('%d/%b/%Y:%H:%M:%S')}  #{msg}" : msg
      if LOG_AGENT_TO_STDOUT
        puts msg
      else
        logger.info(msg)
      end
    end
  
    def guid
      #MGS- returns a unique identifier for the active record object
      # currently used in RSS for guids
      return "uri://skobee.com/#{self.class}/#{self.id}"
    end
  end
end