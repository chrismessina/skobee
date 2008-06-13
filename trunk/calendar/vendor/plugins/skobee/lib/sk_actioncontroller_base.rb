#MES- From C:\ruby\lib\ruby\gems\1.8\gems\actionpack-1.12.1\lib\action_controller\base.rb
module ActionController #:nodoc:
  class Base
  
    #MES- Rename the "original" redirect_to
    alias_method :sk_orig_redirect_to, :redirect_to 
    #MES- Define our own redirect_to, which preserves the flash
    def redirect_to(options = {}, *parameters_for_method_reference) #:doc:
      #MES- Preserve any flash contents
      flash.keep
      #MES- Call the original redirect_to
      sk_orig_redirect_to(options, parameters_for_method_reference)
    end
    
  end
end