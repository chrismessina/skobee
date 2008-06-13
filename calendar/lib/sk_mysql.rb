#KS- the purpose of this class is to intercept all of the calls to mysql and log anything
#that deletes date from the user_atts table. we're doing this because 19 people's zip codes
#disappeared and we can't figure out why... (we suspect it may have something to do with
#the censor_atts method in user_helper though.)
class Mysql

  #KS- make the function name original_query point to query
  alias original_query query

  def query(query)
    #KS- make sure if anything bad goes down in our code, we still execute the original method
    begin
      #KS- if we see "delete" and "user_atts" in the same query string, log it
      if !query.nil? && query_dangerous?(query)
        User.logger.error "##############################################################"
        User.logger.error "dangerous query:"
        User.logger.error query
        User.logger.error "##############################################################"
      end
    rescue Exception
      #KS- don't do anything -- first priority is to make sure original_query executes as normal
    end
    
    #KS- after we're done with our special logging code, call the original method
    original_query(query)
  end
  
  private
  
  def query_dangerous?(query)
    downcased_query = query.downcase
    return (downcased_query.include?('delete') || 
      downcased_query.include?('insert') || 
      downcased_query.include?('update')) && 
      downcased_query.include?('user_atts')
  end
end