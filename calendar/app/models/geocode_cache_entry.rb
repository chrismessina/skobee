#MES- Create a GeocodeInfo struct, to hold info returned by geocoding services
GeocodeInfo = Struct.new(:location, :address, :city, :state, :zip, :lat, :long)

class GeocodeCacheEntry < ActiveRecord::Base

  #KS: not technically correct, but the range is from 68.71 through 69.40 so I
  #figure it's kind of insignificant considering all our error introduced via
  #other sources
  MILES_PER_LAT_DEGREE = 69.0
  
  #KS: array of miles per one degree of longitude at 0 through 80 degrees latitude
  LONGITUDE_MILE_CONVERSION_ARRAY = [ 69.17, 68.13, 65.02, 59.95, 53.06, 44.55, 34.67, 23.73, 12.05 ]
  
  
  def self.find_loc(location)
    #MES- Look up in the cache
    entry = self.find_by_location(location)
    return entry if !entry.nil?
    
    #MES- A cache miss, create a cache entry by geocoding using a service
    geocode_data = self.geocode_via_yahoo(location)
    
    #KS: put all returned location data in the cache.
    #MES- NOTE:  Here, we are using the info returned from our
    # geocoding service as the key (e.g. if the user entered
    # "123 rose lane", but the geocoding service returned
    # "123 Rose Ln", we're keying off of "123 Rose Ln."  This
    # doesn't necessarily help the CURRENT user, but may help the
    # NEXT user that wants to geocode "123 Rose Ln"
    geocode_data.each { | data |
      #MES- Do the cache lookup and cache update in a transaction- we don't want another
      # thread to go adding the cache entry while we're preparing to add it!
      GeocodeCacheEntry.transaction do
        retrieved_entry = GeocodeCacheEntry.find_by_location(data.location)
        if retrieved_entry.nil?
          cache_entry = GeocodeCacheEntry.new
          cache_entry.copy_from data, :location, :address, :city, :zip, :lat, :long
          cache_entry.normalized_location = data.location
          #data is not in cache, put it there
          cache_entry.save
        else
          #data is in cache, update if it's wrong/out of date
          if data.lat != retrieved_entry.lat || 
             data.long != retrieved_entry.long ||
             data.location != retrieved_entry.normalized_location ||
             data.address != retrieved_entry.address ||
             data.city != retrieved_entry.city ||
             data.state != retrieved_entry.state ||
             data.zip != retrieved_entry.zip
            retrieved_entry.normalized_location = data.location
            retrieved_entry.copy_from data, :lat, :long, :address, :city, :state, :zip
            retrieved_entry.save
          end
        end
      end
    }
    
    #KS: if there was only one returned location we have an exact match, put
    #both the original and the normalized data in the cache
    if geocode_data.length == 1    
      #MES- Is another thread also adding the cache entry?
      GeocodeCacheEntry.transaction do
        #MES- Lookup again, to make sure it's not there
        original_location_cache_entry = self.find_by_location(location)
        if original_location_cache_entry.nil?
          data = geocode_data[0]
          #MES- NOTE: Here, we are using the original location, as entered by the user, 
          # as the cache key.  When the user types this address again, they'll get
          # a cache hit.
          original_location_cache_entry = GeocodeCacheEntry.new
          original_location_cache_entry.location = location
          original_location_cache_entry.copy_from data, :lat, :long, :address, :city, :state, :zip
          original_location_cache_entry.normalized_location = data.location
          original_location_cache_entry.save
        end
        return original_location_cache_entry
      end      
    end
    
    #MES- We did not get an exact match, geocoding essentially failed.
    return nil
  end
  
  
  def self.geocode_via_yahoo(location)
    #MES- If nothing was passed in, we're done
    return [] if location.nil? || location.empty?

    app_id = YAHOO_APP_ID
    url = "http://api.local.yahoo.com/MapsService/V1/geocode?appid=#{CGI::escape app_id}"
    url << "&location=#{CGI::escape location}"
    
    res = []
    #MES- Try to find a hit on Yahoo- we might get multiple
    start_time = Time.now
    begin
      open(url) do | f | 
        xmldoc = REXML::Document.new f
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
          #MES- We got some data.  It looks like this:
          #<ResultSet xsi:schemaLocation="urn:yahoo:maps http://api.local.yahoo.com/MapsService/V1/GeocodeResponse.xsd">
          #  <Result precision="address">
          #    <Latitude>37.828595</Latitude>
          #    <Longitude>-122.251363</Longitude>
          #    <Address>4209 HOWE ST</Address>
          #    <City>OAKLAND</City>
          #    <State>CA</State>
          #    <Zip>94611-4704</Zip>
          #    <Country>US</Country>
          #  </Result>
          #</ResultSet>
          xmldoc.elements.each('ResultSet/Result') do | el |
            begin
              #MES- We USED to check for precision, like this:
              #   precision = el.attributes['precision'].to_s
              #   #MES- Did we find an address?
              #   if 'address' == precision
              # but now we want to capture hits that are more generic (e.g. the use entered a zip code)
              loc_arr = []
              address = el.elements['Address'].text.titlecase if !el.elements['Address'].text.nil?
              city = el.elements['City'].text.titlecase if !el.elements['City'].text.nil?
              state = el.elements['State'].text if !el.elements['State'].text.nil?
              zip = el.elements['Zip'].text if !el.elements['Zip'].text.nil?
              loc_arr << address if !address.nil?
              loc_arr << city if !city.nil?
              loc_arr << state if !state.nil?
              loc_arr << zip if !zip.nil?
              info = GeocodeInfo.new(
                loc_arr.compact.join(', '),
                address,
                city,
                state,
                zip,
                el.elements['Latitude'].text.to_f,
                el.elements['Longitude'].text.to_f)
              res << info
            rescue Exception
              xml = ""
              xmldoc.write(xml)
              logger.info("Error occurred while geocoding location #{location}; XML was #{xml}")
            end
          end
        end
      end
    rescue Exception => exc
      logger.info("Error opening URL #{url}: #{exc}")
    end
    logger.info("Geocode lookup for location '#{location}' via yahoo.com took #{Time.now - start_time} seconds")

    return res    
  end
  
  
  def self.get_bounding_box_array(location, max_distance)
    #MES- If the location is a GeocodeCacheEntry, it's the center of the desired bounding box.
    #  If it's not, we need to geocode it.
    geocode_info = nil
    if location.is_a? GeocodeCacheEntry
      geocode_info = location
    else
      geocode_info = GeocodeCacheEntry.find_loc(location)
    end
    
    if !geocode_info.nil?
      #figure out the dimensions of the bounding box in lat/long units from the max_distance
      #TODO: handle singularity at 180/-180 longitude (not much in the way of
      #civilization there, so going to go quick and dirty for now)
      long_degrees_span = max_distance / get_miles_per_long_degree(geocode_info.lat)
      lat_degrees_span = max_distance / MILES_PER_LAT_DEGREE
      lat_least = geocode_info.lat - lat_degrees_span
      lat_most = geocode_info.lat + lat_degrees_span
      long_least = geocode_info.long - long_degrees_span
      long_most = geocode_info.long + long_degrees_span
      
      return [ lat_most, lat_least, long_most, long_least ]
    else
      return nil
    end
  end

  def self.get_miles_per_long_degree(latitude)
    #pull the element out of the conversion array based on which of the 10
    #segments this latitude is in (0-10, 10-20, 20-30, 30-40, 40-50, 50-60, 70-80, 80-90)
    LONGITUDE_MILE_CONVERSION_ARRAY[(latitude).abs / 10]
  end
  
  
#MES- For reference, here's some old code that performs geocoding via geocoder.us.
# Yahoo geocoding seems dramatically faster than geocoder.us
#  PATH_TO_GEOCODER_POINT = 'rdf:RDF/geo:Point'
#  GEOCODER_DESCRIPTION = 'dc:description'
#  GEOCODER_LAT = 'geo:lat'
#  GEOCODER_LONG = 'geo:long'
#  def self.geocode_via_geocoder_us(address)
#    res = []
#    #MES- Try to find a hit on geocoder.us- we might get multiple
#    start_time = Time.now
#    open("http://rpc.geocoder.us/service/rest?address=#{CGI::escape address}") { | f | 
#      xmldoc = REXML::Document.new f
#      xmldoc.elements.each(PATH_TO_GEOCODER_POINT) { | el |
#        desc = el.elements[GEOCODER_DESCRIPTION].text
#        latitude = el.elements[GEOCODER_LAT].text.to_f
#        longitude = el.elements[GEOCODER_LONG].text.to_f
#        
#        res << [desc, latitude, longitude]
#      }
#    }
#    logger.info("Geocode lookup for location '#{address}' via geocoder.us took #{Time.now - start_time} seconds")
#    
#    return res
#  end
end
