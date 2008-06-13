module YahooAPI
  #MGS- library to make use of the Yahoo Web Services API
  # much of this was taken from the cleaner code
  YAHOO_FIELD_TITLE             = 'Title'
  YAHOO_FIELD_ADDRESS           = 'Address'
  YAHOO_FIELD_CITY              = 'City'
  YAHOO_FIELD_STATE             = 'State'
  YAHOO_FIELD_PHONE             = 'Phone'
  YAHOO_FIELD_BUSINESS_URL      = 'BusinessUrl'
  YAHOO_FIELD_YAHOO_LOCAL_URL   = 'Url'

  def simple_local_search(query, location = "", zip = "", radius = 50, results = 20)
    #MGS- helper function to do a 'simple' local search
    # obviously the Y! api has a lot more flexibility than we are using
    url = "http://api.local.yahoo.com/LocalSearchService/V2/localSearch?appid=#{CGI::escape(YAHOO_APP_ID)}"
    url += "&query=#{CGI::escape(query)}"
    url += "&location=#{CGI::escape(location.to_s)}" if "" != location.to_s
    url += "&zip=#{zip.to_s}" if "" != zip.to_s
    url += "&radius=#{radius}"
    url += "&results=#{results}"

    res = []
    open(url) do | f |
      if f.kind_of?(String)
        xmldoc = REXML::Document.new f
      elsif f.kind_of?(StringIO)
        page_string = f.string
        xmldoc = REXML::Document.new page_string
      elsif f.kind_of?(File)
        xmldoc = REXML::Document.new f
      else
        page_string = f.open { | file | file.read }
        xmldoc = REXML::Document.new page_string
      end

      #MES- Was there a result, or an error?  Errors look like this:
      #<Error>
      #  The following errors were detected:
      #  <Message>unable to parse location</Message>
      #</Error>
      if xmldoc.elements['Error']
        logger.info("Error occurred while searching for location #{location} zip #{zip}")
        logger.info("URL requested: #{url}")
        xmldoc.elements.each('Error/Message') do | el |
          raise e
        end
      else
        xmldoc.elements.each('ResultSet/Result') do | el |
          begin
            res << YahooLocalSearchResult.new(el.elements[YAHOO_FIELD_TITLE].text,
                                              el.elements[YAHOO_FIELD_ADDRESS].text,
                                              el.elements[YAHOO_FIELD_CITY].text,
                                              el.elements[YAHOO_FIELD_STATE].text,
                                              el.elements[YAHOO_FIELD_BUSINESS_URL].text,
                                              el.elements[YAHOO_FIELD_YAHOO_LOCAL_URL].text,
                                              el.elements[YAHOO_FIELD_PHONE].text
                                             )
          rescue Exception => e
            raise e
          end
       end
     end
   end
   #MGS- return the array of search result objects
   return res
  end


  class YahooLocalSearchResult
    attr_accessor :name, :address, :city, :state, :url, :yahoo_url, :phone

    def initialize (name, address, city, state, url, yahoo_url, phone)
      self.name = name
      self.address = address
      self.city = city
      self.state = state
      self.url = url
      self.yahoo_url = yahoo_url
      self.phone = phone
    end
  end

end