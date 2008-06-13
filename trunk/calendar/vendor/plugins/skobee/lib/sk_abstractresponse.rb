#MES- From C:\ruby\lib\ruby\gems\1.8\gems\actionpack-1.12.1\lib\action_controller\response.rb
module ActionController
  class AbstractResponse
    #MGS- overriding rails default HTTP headers; adding 'no-store'
    # This works around a Firefox feature where the back button doesn't reload the page.
    DEFAULT_HEADERS = { "Cache-Control" => "no-cache,no-store" }
  end
end