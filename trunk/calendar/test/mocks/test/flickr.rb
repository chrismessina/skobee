#MES- Override the flickr class, so that we do NOT do (slow) network calls
#  when running tests


class Flickr
  def initialize(api_key='86e18ef2a064ff2255845e029208d7f4', email=nil, password=nil)
  end
  
  def users(lookup=nil)
    return User.new(lookup)
  end  
  
  def photos_fixed(*criteria)
    res = []
    user_id = criteria[0][:user_id]
    user_id = 'no_id' if user_id.nil?
    per_page = criteria[0][:per_page].to_i
    per_page = 20 if per_page > 20
    1.upto(per_page) do | idx |
      res << Photo.new(user_id)
    end
    
    return res
  end
  
  class User
    def initialize(id=nil, username=nil, email=nil, password=nil)
      @id = id
    end
  end
  
  class Photo
    def initialize(id=nil)
      @id = id
    end
    
    def sizes()
      return [{'label' => 'Thumbnail', 'source' => 'dummy_source_' + @id, 'url' => 'dummy_url_' + @id}, {'label' => 'Original', 'source' => 'dummy_source_' + @id, 'url' => 'dummy_url_' + @id}]
    end
  end
end