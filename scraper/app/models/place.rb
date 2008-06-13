require 'open-uri'

class Place < ActiveRecord::Base
  #KS- different potential origins for places
  ORIGIN_YELLOWPAGES = 0
  ORIGIN_YAHOO = 1
  
  #KS- different things that can happen from a yahoo request
  ADDED_FROM_YAHOO = 0
  CLEANED = 1
  DELETED = 2
  
  #KS- name of the file to store completed log in
  COMPLETED_LOG_NAME = 'redo.txt'
  
  #KS- name of the file to look for the last index to do a clean on (used for parallelization)
  STOP_NUMBER_FILE_NAME = 'stop_at.txt'
  
  #KS- name of file to store cleaned place indices in
  CLEANED_PLACE_LOG_NAME = 'cleaned_place.txt'
  
  #KS- name of the file with the completed (important) states
  CLEANED_STATES = 'cleaned_states.txt'
  
  #KS- list of the banned keywords (we don't wanna bother cleaning these initially)
  BANNED_KEYWORDS_FILE_NAME = 'banned_keywords.txt'
  
  #KS- this is here because it must come before the array
  def self.get_processed_states
    states = []
    if File.exist? CLEANED_STATES
      File.open(CLEANED_STATES, 'r') do |file|
      
        while line = file.gets
          if !line.blank?
            new_state = line.strip
        
            if !states.include? new_state
              states << new_state
            end
          end
        end
      end
    end
    
    return states
  end
  
  #KS- place to write queries/pages with >4001 problem
  PROBLEM_LOG = 'problem_log.txt'
  
  #KS- the file that contains the number of scrapers in action and the file that
  #contains this user's assigned mod number
  NUM_CLEANERS_FILE_NAME = 'num_cleaners.txt'
  MOD_NUM_FILE_NAME = 'mod_nums.txt'
  
  #KS- scraper mod num filename
  NUM_SCRAPERS_FILE_NAME = 'num_scrapers.txt'
  SCRAPER_MOD_NUM_FILE_NAME = 'scraper_mod_nums.txt'
  
  #KS- db reconnect params
  DB_CONNECT_ERROR_SLEEP_SECS = 6
  DB_CONNECT_ERROR_LIMIT = 10*60*24
  
  #KS- couldn't figure out how to get the max int value so use this for now
  HUGE_INT = 99999999

  #KS- weighted array of user-agent strings so that when we select random ones it's biased towards IE
  USER_AGENTS = [ 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; SV1; .NET CLR 1.1.4322)',
                  'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.12) Gecko/20050915 Firefox/1.0.7',
                  'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.12) Gecko/20050915 Firefox/1.0.7',
                  'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.12) Gecko/20050915 Firefox/1.0.7',
                  'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8b4) Gecko/20050908 Firefox/1.4',
                  'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8b4) Gecko/20050908 Firefox/1.4'
  ].freeze

  ZIPCODES = [ 
    '94105', #SF
    '10001', #NYC
    '90001', #LA
    '60601', #Chicago
    '77002', #houston (texas)
    '19102', #philadelphia (pennsylvania)
    '85003', #Phoenix (Arizona)
    '92101', #San Diego (CA)
    '78201', #san antonio (texas)
    '75201', #dallas (texas)
    '95101', #San Jose (CA)
    '48201', #detroit (michigan)
    '46201', #Indianapolis (Indiana)
    '32099', #jacksonville (florida)
    '43201', #columbus (ohio)
    '78701', #austin (texas)
    '38103', #memphis (tennessee)
    '21201', #baltimore (maryland)
    '98101', #Seattle
    '97201', #Portland
    '85701', #Tucson (Arizona)
    '99501', #Anchorage (Alaska)
    '99801', #Juneau (Alaska)
    '35203', #Birmingham (Alabama)
    '36602', #Mobile (Alabama)
    '36104', #Montgomery (Alabama)
    '86001', #Flagstaff (Arizona)
    '72701', #Fayetteville (Arkansas)
    '72201', #Little Rock (Arkansas)
    '80903', #Colorado Springs
    '80012', #Denver (CO)
    '06810', #Danbury (CT)
    '06101', #Hartford (CT)
    '06510', #New Haven (CT)
    '06320', #New London (CT)
    '06901', #Stamford (CT)
    '20001', #Washington DC
    '19801', #Wilmington (Delaware)
    '33109', #Miami (FL)
    '32801', #Orlando (FL)
    '32301', #Tallahassee (FL)
    '33602', #Tampa (FL)
    '33401', #West Palm Beach (FL)
    '30303', #Atlanta (GA)
    '31401', #Savannah (GA)
    '96813', #Honolulu (Hawaii)
    '83702', #Boise (Idaho)
    '62701', #Springfield (IL)
    '50307', #Des Moines (Iowa)
    '66044', #Lawrence (Kansas)
    '66603', #Topeka (Kansas)
    '67202', #WICHITA (kansas)
    '40502', #Lexington (kentucky)
    '40202', #Louisville (kentucky)
    '70112', #New Orleans (louisiana)
    '04101', #portland (maine)
    '02108', #boston (massachussetts)
    '49503', #grand rapids (michigan)
    '55401', #minneapolis (minnesota)
    '39201', #jackson (mississippi)
    '64101', #kansas city (missouri)
    '63101', #st louis (missouri)
    '65802', #springfield (missouri)
    '59601', #helena (montana)
    '68102', #omaha (nebraska)
    '89701', #carson city (nevada)
    '89044', #las vegas (nevada)
    '89501', #reno (nevada)
    '03301', #concord (new hampshire)
    '03101', #manchester (new hampshire)
    '08401', #atlantic city (new jersey)
    '87101', #albequerque (new mexico)
    '87501', #santa fe (new mexico)
    '14201', #buffalo (new york)
    '14603', #rochester (new york)
    '28801', #asheville (North Carolina)
    '28202', #charlotte (north carolina)
    '27601', #raleigh (north carolina)
    '58501', #bismarck (north dakota)
    '45202', #cincinatti (ohio)
    '44102', #cleveland (ohio)
    '43601', #toledo (ohio)
    '73102', #oklahoma city (oklahoma)
    '74103', #tulsa (oklahoma)
    '15203', #pittsburgh (pennsylvania)
    '02903', #providence (rhode island)
    '29401', #charleston (south carolina)
    '29572', #myrtle beach (south carolina)
    '57501', #pierre (south dakota)
    '57103', #sioux falls (south dakota)
    '37902', #knoxville (tennessee)
    '37201', #nashville (tennessee)
    '78401', #corpus christi (texas)
    '79901', #el paso (texas)
    '76001', #arlington (texas)
    '84101', #salt lake city (utah)
    '05602', #montpelier (vermont)
    '23219', #richmond (virginia)
    '23451', #virginia beach (virginia)
    '99201', #spokane (washington)
    '25301', #charleston (west virginia)
    '53703', #madison (wisconsin)
    '53202', #milwaukee (wisonsin)
    '82001', #cheyenne (wyoming)
    '83001', #jackson hole (wyoming)
    '93650', #Fresno (CA)
    '90745', #Long Beach (CA)
    '93940', #Monterey (CA)
    '94601', #Oakland (CA)
    '92602', #Irvine (Orange County, CA)
    '92262', #Palm Springs (CA)
    '95814', #Sacramento (CA)
    '93101' #Santa Barbara (CA)
  ].freeze
  
  QUERIES = [ 'restaurant', 'coffee houses', 'cocktail lounges', 'night clubs', 'day spas', 'movie theaters', 'theatres', 'concert halls', 'venues' ]
  
  IMPORTANT_STATE_ARRAY = [ 'CA', 'NY', 'NJ', 'WA', 'TX', 'MA', 'FL', 'IL' ].freeze
  
  #KS- use this to determine how long to sleep during yahoo exceptions
  INITIAL_YAHOO_SLEEP_SECONDS = 60
  
  #KS- don't sleep more than this many seconds
  YAHOO_SLEEP_SECONDS_MAX = 60 * 60

  #KS- keep track of the number of yahoo requests made
  @@num_yahoo_requests = 0
  
  #KS- make the mod number a class variable
  @@assigned_mod_nums = 0

  def self.run    
    @num_scrapers = get_max_int_in_file(NUM_SCRAPERS_FILE_NAME)
    @scraper_mod_nums = get_int_array_from_file(SCRAPER_MOD_NUM_FILE_NAME)
  
    zip_query_hash = read_completed_queries
    
    ZIPCODES.each{|zip|
      p "zip: #{zip}"
      if zip_query_hash["#{zip}, *"] != '*'
        QUERIES.each{|query| 
          page_value = zip_query_hash["#{zip}, #{query}"]
          if page_value != '*' && !page_value.nil?
            p "page value! #{page_value}"
            p "starting query #{query} in zip #{zip}"
            start_page = page_value.nil? ? 1 : page_value.to_i
            p "$$$$$$$$$$$$$$$start page is: #{start_page} for \'#{zip}, #{query}\'"
            p "page_value: #{page_value}"
            grab_location_entries(HUGE_INT, start_page, query, zip)
            
            #KS- this means we are completely done with this zip/query combo
            write_to_completed("#{zip}, #{query}, *")
          end
        }
        
        #KS- this means we are completely done with this zip
        write_to_completed("#{zip}, *, *")
      end
    }
  end
  
  def self.get_string_array_from_file(filename)
    string_array = []
    if File.exist? filename
      lines_array = []
      File.open(filename, 'r') do |file|
        lines_array = file.readlines
      end
      
      lines_array.each{|line|
        index = line.strip
        string_array << index
      }
    else
      raise "ERROR: COULD NOT FIND THE FILE #{filename}!"
    end
    
    return string_array
  end
  
  def self.get_int_array_from_file(filename)
    int_array = []
    if File.exist? filename
      lines_array = []
      File.open(filename, 'r') do |file|
        lines_array = file.readlines
      end
      
      lines_array.each{|line|
        index = line.strip.to_i
        int_array << index
      }
    else
      raise "ERROR: COULD NOT FIND THE FILE #{filename}!"
    end
    
    return int_array
  end
  
  def self.test_get_int_array_from_file
    array = get_int_array_from_file('scraper_mod_nums.txt')
    
    array.each{|element|
      p element
    }
  end
  
  def self.get_max_int_in_file(filename)
    max_index = nil
    if File.exist? filename
      max_index = 0
    
      lines_array = []
      File.open(filename, 'r') do |file|
        lines_array = file.readlines
      end
      
      lines_array.each{|line|
        index = line.strip.to_i
        if index > max_index
          max_index = index
        end
      }
    end
    
    return max_index
  end
  
  #KS- clean the data by running it through yahoo's superior local search api
  def self.clean_places
    p "beginning clean places..."
    
    #KS- get the largest index that's been cleansed. default 0
    #max_index = get_max_int_in_file(CLEANED_PLACE_LOG_NAME)
    max_index = 0 if max_index.nil?
    
    conditions_string = "id > :min_id AND deleted_by_clean IS NULL AND id % :num_scrapers in (:assigned_mod_nums)"
    
    #KS- read in num_scrapers and assigned_mod_nums
    num_scrapers = get_max_int_in_file(NUM_CLEANERS_FILE_NAME)
    @@assigned_mod_nums = get_int_array_from_file(MOD_NUM_FILE_NAME)
    
    #KS- read in banned keywords
    banned_keywords = get_string_array_from_file(BANNED_KEYWORDS_FILE_NAME)
    
    #KS- add banned keywords to conditions_string
    banned_keywords.each{|banned_keyword|
      conditions_string += " AND name NOT LIKE '%#{banned_keyword}%'"
    }
    
    p "here ya go"
    @@assigned_mod_nums.each{|nums|
      p nums
    }
    
    conditions_hash = { :min_id => max_index, :num_scrapers => num_scrapers, :assigned_mod_nums => @@assigned_mod_nums }
  
    #KS- array that holds processed states
    #processed_states_array = Place.get_processed_states
    processed_states_array = []
    
    IMPORTANT_STATE_ARRAY.each{|state|
      if !processed_states_array.include? state
        p "looking for stuff in #{state}"
        conditions_string_with_states = conditions_string + " AND state = :state"
        conditions_hash[:state] = state
        clean_inner_loop(conditions_string_with_states, conditions_hash)
        
        write_to_file(CLEANED_STATES, state)
        conditions_hash[:min_id] = 0
      end
    }
    
    #KS- if done with all states, loop on all the other crap
    conditions_hash.delete(:state)
    clean_inner_loop(conditions_string, conditions_hash)
  end
  
  def self.clean_inner_loop(conditions_string, conditions_hash)    
    yahoo_sleep_seconds = INITIAL_YAHOO_SLEEP_SECONDS
    
    places = Place.find(:all, :conditions => [ conditions_string, conditions_hash ], :limit => 1000)
    
    p "conditions: #{conditions_string}"
    conditions_hash.each{|param, value|
      p "condition: #{param}, value: #{value}"
    }
    p "found #{places.length} places..."
    
    while !places.nil? && !places.empty?
      places.each{|place| 
        begin
          #KS- make sure the db connection is fresh
          freshen_db_connection
        
          #KS- print some debug info
          p "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
          p "cleaning '#{place.name}' -- this SHOULD NOT CONTAIN BANNED KEYWORDS!"
          p "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
        
          place.clean_and_save
          
          #KS- reset the sleep seconds to its initial value if we saved successfully
          yahoo_sleep_seconds = INITIAL_YAHOO_SLEEP_SECONDS
        rescue Exception => e
          p e
          
          #KS- only raise during debugging
          #raise e
          
          #KS- sleep for a bit so that we don't piss off yahoo
          p "**********************************************************************"
          p "sleeping for #{yahoo_sleep_seconds / 60} minutes"
          p "**********************************************************************"
          sleep yahoo_sleep_seconds
          
          #KS- if we sleep again, sleep for twice as long (if it's not past max)
          yahoo_sleep_seconds = [yahoo_sleep_seconds * 2, YAHOO_SLEEP_SECONDS_MAX].min
          
          #KS- redo the loop
          redo
        end
        
        p "completed place #{place.id}"
        write_to_cleaned(place.id)
      }
      
      conditions_hash[:min_id] += places.length
      places = Place.find(:all, :conditions => [ conditions_string, conditions_hash ], :limit => 1000)
    end
  end
  
  def self.write_to_file(filename, string)
    File.open(filename, 'a') do |file|
      file.write("\n#{string}")
    end
  end
  
  def self.write_to_cleaned(string)
    File.open(CLEANED_PLACE_LOG_NAME, 'a') do |file|
      file.write("\n#{string}")
    end
  end
  
  def self.write_to_completed(string)
    File.open(COMPLETED_LOG_NAME, 'a') do |file|
      file.write("\n#{string}")
    end
  end
  
  def self.write_to_problem(zip, query)
    File.open(PROBLEM_LOG, 'a') do |file|
      file.write("\n#{zip}, #{query}")
    end
  end
  
  def self.read_completed_queries
    hash = {}
    if File.exist? COMPLETED_LOG_NAME
      lines_array = []
      File.open(COMPLETED_LOG_NAME, 'r') do |file|
        lines_array = file.readlines
      end
      
      line_array = []
      lines_array.each{|line|
        if !line.strip.empty?
          p "read line: \'#{line}\'"
          line_array = line.split(',')
          
          #KS- is it in the hash already?
          key = line_array[0].strip + ', ' + line_array[1].strip
          element = hash[key]
          if element.nil?
            hash[key] = line_array[2].strip
          else
            if line_array[1].strip == '*'
              hash[key] = '*'
            elsif line_array[2].strip == '*'
              hash[key] = '*'
            elsif element != '*' && element.to_i < line_array[2].strip.to_i
              hash[key] = line_array[2].strip
            end
          end
        else
          p "no line read"
        end
      }
      
      p '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@'
      hash.each{|key, value| p "key: \'#{key}\', value: \'#{value}\'"}
      p '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@'
    end
    
    return hash
  end
  
  def self.get_random_user_agent_string
    USER_AGENTS[rand(USER_AGENTS.length)]
  end
  
  def self.test
    string = <<-END_OF_STRING
		<div class="ypBAddress">298 9th St<br>San Francisco, CA 94103</div><br>

		
		
	
	
	
	
	
	
	
	
	(415) 864-7425
    END_OF_STRING
    
    /\<div class\=\"ypBAddress\"\>(.*)\,\s([A-Z]{2})\s(\d\d\d\d\d)\<\/div\>\<br\>[.\s]*(\(\d\d\d\)\s\d\d\d\-\d\d\d\d)/n =~ string
    p $1
  end
  
  def self.freshen_db_connection
    error_count = 0
    while !connection.active?
      p "reconnecting to db..."
      #MES- Try reconnecting to the DB
      begin
        connection.reconnect!
      rescue Exception => exc
        #MES- An error connecting, wait a bit and see if the DB comes back
        p "Error when connecting to DB:"
        p exc
        error_count = error_count + 1
        if DB_CONNECT_ERROR_LIMIT < error_count
          p "Over #{EMAIL_DB_CONNECT_ERROR_LIMIT} errors detected when trying to connect to the DB- exiting"
          exit!
        end
        sleep DB_CONNECT_ERROR_SLEEP_SECS
      end
    end
  end
  
  def self.grab_location_entries(total_page_count, start, query, zip)
    page_count = start
    escaped_query = CGI::escape(query)
    redo_count = 0
    while page_count <= total_page_count
      #KS- yellowpages.com craps out at page 4002 -- record it if we hit this page
      if page_count >= 4002 && total_page_count != HUGE_INT
        write_to_problem(zip, query)
        
        #KS- done with this loop
        break
      end
      
      #KS- make sure the db connection is fresh
      freshen_db_connection
      
      if @scraper_mod_nums.include?(page_count % @num_scrapers) || page_count == start
        url = "http://www.yellowpages.com/sp/yellowpages/ypresults.jsp?t=1&v=1&s=0&p=#{page_count}&q=#{escaped_query}&r=500&st=CA&zp=#{zip}&q=#{escaped_query}"
        p "########################################################################"
        p url
        p "page: #{page_count} / #{total_page_count} of #{query} query"
        p "########################################################################"
        #MES- Try to find a hit on Yahoo- we might get multiple
        start_time = Time.now
        begin
          page_string = ''
          open(url, "User-Agent" => get_random_user_agent_string) do | f | 
            if f.kind_of? String
              page_string = f
            elsif f.kind_of? StringIO
              page_string = f.string
            elsif f.kind_of? IO
              page_string = f.open { | file | file.read }
            else
              page_string = f.read
            end
          end
          
          /<b>All \((\d+)\)<\/b><\/td>/ =~ page_string
          total_results = $1.to_i
          total_page_count = (total_results / 25.0).ceil
          
          #KS- if the page count is bad, throw this shit away and request the url again
          if total_page_count == 0
            p "page count was bad, redo (#{redo_count})!"
            if redo_count < 50
              redo_count += 1
              redo
            else
              write_to_problem(zip, query)
              redo_count = 0
              return
            end
          else
            redo_count = 0
          end
          
          p "total calculated page count: #{total_page_count}"
          
          total_time = Time.now - start_time
            
            while /\<div class\=\"ypBName\"\>[.\s]*\<a href=\"(.*)\"\>(.*)\<\/a\>[.\s]*\<\/div\>/n =~ page_string
              #KS- remove everything up to the end of the name of the next place
              index = /\<div class\=\"ypBName\"\>[.\s]*\<a href=\"(.*)\"\>(.*)\<\/a\>[.\s]*\<\/div\>/n =~ page_string
              page_string = page_string[index + $&.length, page_string.length]
              
              newplace = Place.new
              
              newplace.url = $1
              newplace.name = $2
              newplace.normalize_name!
              p $2
              
              /\<div class\=\"ypBAddress\"\>(.*)\<br\>(.*)\,\s([A-Z]{2})\s(\d\d\d\d\d)\<\/div\>\<br\>[.\s]*(\(\d\d\d\)\s\d\d\d\-\d\d\d\d)/n =~ page_string
              if !$&.nil? && !$&.empty?
                newplace.location = "#{$1}, #{$2}, #{$3}, #{$4}"
                newplace.address = $1
                newplace.city = $2
                newplace.state = $3
                newplace.zip = $4
                newplace.phone = $5
                newplace.meta_info = "#{newplace.meta_info} #{query}".strip
                newplace.origin = ORIGIN_YELLOWPAGES
                
                newplace.save
              end
            end
            
        rescue Exception => exc
          p exc
          #raise exc
          redo
        end
        
        write_to_completed("#{zip}, #{query}, #{page_count}")
        
        scraped_page = ScrapedPage.new
        scraped_page.zip = zip
        scraped_page.page = page_count
        scraped_page.total_pages = total_page_count
        scraped_page.save
        
        p "request took #{total_time} seconds..."
        sleep 0.2
      end
      
      #KS- always increment the page count  
      page_count += 1
    end
  end
  
  #KS- use this to make sure the normalized_name / location combo is unique before
  #writing to the database
  def validate
    conditions_string = "normalized_name = :normalized_name AND address = :address AND city = :city AND state = :state"
    conditions_values = { :normalized_name => self.normalized_name, :address => self.address, :city => self.city, :state => self.state }
    if !id.nil?
      conditions_string += " AND id != :id"
      conditions_values[:id] = self.id
    end
    if !zip.nil?
      conditions_string += " AND zip = :zip"
      conditions_values[:zip] = self.zip
    end
    
    result = Place.find(:first, :conditions => [ conditions_string, conditions_values ])
    
    if !result.nil?
      dupe = DuplicateTracker.new
      dupe.place_id = result.id
      dupe.save
    
      error_string = "place #{self.id}: #{self.name} at #{self.address} is a duplicate of #{result.id}: #{result.name} at #{result.address}!"
#      p "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
#      p error_string
#      p "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
      errors.add error_string
    end
  end
  
  #KS- clean this place by running it through yahoo's local search api
  def clean_and_save
    begin
      num_results = clean_save_helper
       
      #KS- if there were no results, blow away the place because it wasn't found in yahoo
      if num_results == 0
        p "deleting bogus place \'#{name}\' because no results were found"
        self.deleted_by_clean = 1
        self.save
        
        #KS- search 25 miles around the zip code for anything with the same
        #name and add them all to the database
        clean_save_helper(nil, 25, 20, nil, self.zip, true)
      end
    rescue Exception => exc
      p exc
      logger.info("Error opening URL #{url}: #{exc}")
      raise exc
    end
  end
  
  def clean_save_helper(place = self, radius = 0.1, num_results = 1, address = self.address, zip = self.zip, find_places_on_yahoo_by_name = false)
    app_id = YAHOO_APP_ID
    
    if place.nil?
      p "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
      p "doing fresh lookup for #{self.name} in #{self.city}, #{self.state}"
      p "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
    end
    
    url = "http://api.local.yahoo.com/LocalSearchService/V2/localSearch?appid=#{CGI::escape app_id}&radius=#{radius}&city=#{CGI::escape city}&state=#{CGI::escape state}&query=#{CGI::escape name}&zip=#{CGI::escape zip}&results=#{num_results}"
    if !address.nil?
      url += "&street=#{CGI::escape address}"
    end
    
    #KS- keep count of how many results there are
    counter = 0
    
    open(url) do | f | 
      if f.kind_of?(String)
        xmldoc = REXML::Document.new f
      elsif f.kind_of?(StringIO)
        page_string = f.string
        xmldoc = REXML::Document.new page_string
      else
        page_string = f.open { | file | file.read }
        xmldoc = REXML::Document.new page_string
      end
          
      @@num_yahoo_requests += 1
      p "num yahoo requests made: #{@@num_yahoo_requests}"
      request_tracker = YahooRequestTracker.new
      request_tracker.request_num = @@num_yahoo_requests
      request_tracker.resolution = ADDED_FROM_YAHOO if find_places_on_yahoo_by_name
      request_tracker.mod_num = @@assigned_mod_nums[0]
      
      #MES- Was there a result, or an error?  Errors look like this:
      #<Error>
	#  The following errors were detected:
      #  <Message>unable to parse location</Message>
      #</Error>
      if xmldoc.elements['Error']
        logger.info("Error occurred while geocoding location #{location}")
        xmldoc.elements.each('Error/Message') do | el |
          logger.info("  XML error: #{el.text}")
        end
      else
        xmldoc.elements.each('ResultSet/Result') do | el |
          place = Place.new if find_places_on_yahoo_by_name
        
          begin
            counter += 1
            temp_address = el.elements['Address'].text
            temp_city = el.elements['City'].text
            temp_state = el.elements['State'].text
            temp_name = el.elements['Title'].text
            url_element = el.elements['Url']
            temp_yahoo_url = url_element.nil? ? nil : url_element.text
            yahoo_click_url_element = el.elements['ClickUrl']
            temp_yahoo_click_url = yahoo_click_url_element.nil? ? nil : yahoo_click_url_element.text
            business_url_element = el.elements['BusinessUrl']
            temp_url = business_url_element.nil? ? nil : business_url_element.text
            business_click_url_element = el.elements['BusinessClickUrl']
            temp_click_url = business_click_url_element.nil? ? nil : business_click_url_element.text
            temp_phone = el.elements['Phone'].text
            temp_lat = el.elements['Latitude'].text
            temp_long = el.elements['Longitude'].text
            temp_avg_rating = el.elements['Rating/AverageRating'].text
            temp_total_ratings = el.elements['Rating/TotalRatings'].text
            temp_total_reviews = el.elements['Rating/TotalReviews'].text
            temp_last_review_date = el.elements['Rating/TotalReviews'].text
            
            if temp_address.nil? || temp_city.nil? || temp_state.nil? || temp_name.nil? || temp_phone.nil? || temp_long.nil? || temp_lat.nil?
              component = 'unknown'
              if temp_address.nil?
                component = 'address'
              elsif temp_city.nil?
                component = 'city'
              elsif temp_state.nil?
                component = 'state'
              elsif temp_name.nil?
                component = 'name'
              elsif temp_phone.nil?
                component = 'phone'
              elsif temp_long.nil?
                component = 'longitude'
              elsif temp_lat.nil?
                component = 'latitude'
              end
              p "deleting bogus place \'#{place.name}\' in #{place.city}, #{place.state} because #{component} wasn't found"
              place.deleted_by_clean = 1
              place.save
              request_tracker.resolution = DELETED
            else
              p "found place \'#{temp_name}\', in #{temp_city}, #{temp_state} in Y!"
              place.address = temp_address.titlecase if !temp_address.nil?
              place.city = temp_city.titlecase
              place.state = temp_state
              place.name = temp_name
              place.normalize_name!
              place.yahoo_url = temp_yahoo_url
              place.yahoo_click_url = temp_yahoo_click_url
              place.url = temp_url
              place.click_url = temp_click_url
              place.phone = temp_phone
              place.normalize_phone!
              place.lat = temp_lat
              place.long = temp_long
              place.geocoded = 1
              place.deleted_by_clean = 0
              request_tracker.resolution = CLEANED
              
              #KS- re-add these for the yahoo searching by name
              if find_places_on_yahoo_by_name
                place.public = 1
                place.location = place.address + ", " + city + ", " + state
                
                #KS- make the origin yahoo since this stuff didn't come from yellowpages
                place.origin = ORIGIN_YAHOO
                
                #KS- we don't know the zip from the location search, so we'll
                #have to get it from yahoo later by re-geocoding or doing some
                #sort of location search
                place.geocoded = 0
                
                #KS- we added it from yahoo
                request_tracker.resolution = ADDED_FROM_YAHOO
              else
                #KS- it was cleaned, not added, so set the clean time
                place.cleaned_at = Time.now
                
                #KS- we cleaned an existing place
                request_tracker.resolution = CLEANED
              end
              
              if !temp_avg_rating.nil? && !temp_avg_rating.empty? && temp_avg_rating != 'NaN'
                place.average_rating = temp_avg_rating
              end
              if !temp_total_ratings.nil?
                place.total_ratings = temp_total_ratings
              end
              if !temp_total_reviews.nil?
                place.total_reviews = temp_total_reviews
              end
              if !temp_last_review_date.nil? && temp_last_review_date != 0
                place.last_review_date = temp_last_review_date
              end
              
              if !place.save
                #KS- once run through yahoo, a duplicate was found...
                #set deleted_by_clean to 1 if it's already in the db
                if !place.id.nil?
                  p "duplicate found! deleting #{place.id}: \'#{place.name}\' in #{place.city}, #{place.state}"
                  place = Place.find(place.id)
                  place.deleted_by_clean = 1
                  place.save
                  
                  #KS- set the duplicate setting to 1 in the request_tracker
                  request_tracker.duplicate = 1
                end
              end
              
              #KS- save the request tracker info
              request_tracker.save
            end
          rescue Exception => e
            xml = ""
            xmldoc.write(xml)
            logger.info("Error occurred while geocoding location #{location}; XML was #{xml}")
            raise e
          end
        end
      end
    end
    
    #KS- return the number of results
    return counter
  end
  
  def normalize_name!
    #MES- Set the "normalized_name" field based on the name field.
    # It's basically the same, but lowercase and alphanumeric only.
    if name.nil?
      self.normalized_name = nil
    else
      self.normalized_name = name.downcase.delete('^a-z0-9 ')
    end
  end  
  
  def normalize_phone!
    #MES- If the phone number is set, fix it up to be our normalized format.
    # The normalized format is basically all numbers (no dashes, parens, etc.)
    # and any leading '1's are stripped.
    # E.g. '1 (415) 399-2676' would be stored at '4153992676'
    if !self.phone.nil?
      #MES- Strip out any non-numeric characters, and delete any leading '1's
      self.phone = self.phone.delete('^0-9').match('(1)*(.*)')[2]      
    end
  end
end
