#MES- From C:\ruby\lib\ruby\gems\1.8\gems\flickr-1.0.0\flickr.rb
class Flickr
  def photos_fixed(*criteria)
    photos = (criteria[0]) ? photos_search(criteria[0]) : photos_getRecent
    photo_arr = photos['photos']['photo']
    #MES- The original version of this function did NOT handle the case where
    # the return is not an array
    if photo_arr.instance_of? Array
      return photo_arr.collect { |photo| Photo.new(photo['id']) }
    else
      return [Photo.new(photo_arr['id'])]
    end
  end
end