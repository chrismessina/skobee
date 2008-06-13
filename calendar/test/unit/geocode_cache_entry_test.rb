require File.dirname(__FILE__) + '/../test_helper'

class GeocodeCacheEntryTest < Test::Unit::TestCase
  fixtures :geocode_cache_entries

  def test_cache_hit
    cache_entry = GeocodeCacheEntry.find_loc('blahbittyblah')
    assert !cache_entry.nil?
    assert_equal 123, cache_entry.lat
    assert_equal 1234, cache_entry.long
  end
  
  def test_created_at
    cache_entry = GeocodeCacheEntry.new
    cache_entry.save
    
    ce2 = GeocodeCacheEntry.find(cache_entry.id)
    assert !ce2.created_at.nil?
  end
  
  def test_cache_miss
  
    mock_opens = {
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=2236+Carmel+Valley+Rd%2C+Del+Mar%2C+CA' => './test/mocks/resources/2236_Carmel_Valley.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=94611-4704' => './test/mocks/resources/94611_4704.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=some+garbage' => './test/mocks/resources/some_garbage.xml',
    }
    with_mock_opens(mock_opens) do
      #MES- There should not be an entry in the DB to start with for a "good" address
      assert_equal 0, User.connection.select_all("SELECT COUNT(*) AS CT FROM geocode_cache_entries WHERE location = '2236 Carmel Valley Rd, Del Mar, CA'")[0]['CT'].to_i
      cache_entry = GeocodeCacheEntry.find_loc('2236 Carmel Valley Rd, Del Mar, CA')
      assert_equal '2236 Carmel Valley Rd, Del Mar, CA', cache_entry.location
      assert_equal '2236 Carmel Valley Rd, Del Mar, CA, 92014-3704', cache_entry.normalized_location
      #MES- The cache should now have an entry for that address
      assert_equal 1, User.connection.select_all("SELECT COUNT(*) AS CT FROM geocode_cache_entries WHERE location = '2236 Carmel Valley Rd, Del Mar, CA'")[0]['CT'].to_i
      #MES- It should also have an address for the canonicalized address
      assert_equal 1, User.connection.select_all("SELECT COUNT(*) AS CT FROM geocode_cache_entries WHERE location = '2236 Carmel Valley Rd, Del Mar, CA, 92014-3704'")[0]['CT'].to_i
      
      #MES- Looking up a vague address should work
      assert_equal 0, User.connection.select_all("SELECT COUNT(*) AS CT FROM geocode_cache_entries WHERE location = '94611-4704'")[0]['CT'].to_i
      cache_entry = GeocodeCacheEntry.find_loc('94611-4704')
      assert_equal '94611-4704', cache_entry.location
      assert_equal 'Oakland, CA, 94611-4704', cache_entry.normalized_location
      assert_equal 1, User.connection.select_all("SELECT COUNT(*) AS CT FROM geocode_cache_entries WHERE location = '94611-4704'")[0]['CT'].to_i
      assert_equal 1, User.connection.select_all("SELECT COUNT(*) AS CT FROM geocode_cache_entries WHERE location = 'Oakland, CA, 94611-4704'")[0]['CT'].to_i
      
      #MES- Looking up a garbage address should fail
      cache_entry = GeocodeCacheEntry.find_loc('some garbage')
      assert cache_entry.nil?
    end
  end
  
  def test_get_bounding_box_array
    
    mock_opens = {
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=2236+Carmel+Valley+Rd%2C+Del+Mar%2C+CA' => './test/mocks/resources/2236_Carmel_Valley.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=94611-4704' => './test/mocks/resources/94611_4704.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=some+garbage' => './test/mocks/resources/some_garbage.xml',
    }
    with_mock_opens(mock_opens) do
      bounding_box = GeocodeCacheEntry.get_bounding_box_array('94611-4704', 5)
      
      assert_equal 4, bounding_box.length
      assert_equal(3790126, (bounding_box[0] * 100000).floor)
      assert_equal(3775633, (bounding_box[1] * 100000).floor)
      assert_equal(-12216760, (bounding_box[2] * 100000).floor)
      assert_equal(-12233441, (bounding_box[3] * 100000).floor)
      
      
      bounding_box = GeocodeCacheEntry.get_bounding_box_array('some garbage', 5)
      assert_nil bounding_box
    end
  end
end
