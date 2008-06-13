require File.dirname(__FILE__) + '/../test_helper'

class YahooAPITest < Test::Unit::TestCase
  include YahooAPI

  def test_simple_local_search
    #MGS- test the yahoo api local search api
    mock_opens = {
      'http://api.local.yahoo.com/LocalSearchService/V2/localSearch?appid=just_to_test&query=peets&zip=94109&radius=50&results=20' => './test/mocks/resources/peets_94109.xml',
      'http://api.local.yahoo.com/LocalSearchService/V2/localSearch?appid=just_to_test&query=taco+bell&location=6160+Park+Ave%2C+Memphis%2C+TN&radius=50&results=20' => './test/mocks/resources/taco_bell_memphis.xml',
    }
    with_mock_opens(mock_opens) do
      #MGS- make a search with a zipcode and not a location
      res = simple_local_search("peets", '', 94109)
      assert_equal 20, res.length

      res1 = res[0]
      assert_equal "Peets Coffee & Tea", res1.name
      assert_equal "401 Broadway", res1.address
      assert_equal "San Francisco", res1.city
      assert_equal "CA", res1.state
      assert_nil res1.url
      assert_equal "http://local.yahoo.com/details?id=28806057&stx=peets&csz=San+Francisco+CA&ed=YyRbf6160SywxvXmPnarSuK97i83wWPGbUDMtbtUvXLo0O3hqcMEZ3_O0w1xW5kduQoPeg--", res1.yahoo_url

      res2 = res[19]
      assert_equal "Peet's Coffee & Tea Incorporated", res2.name
      assert_equal "88 Throckmorton Ave", res2.address
      assert_equal "Mill Valley", res2.city
      assert_equal "CA", res2.state
      assert_equal "http://peets.com/", res2.url
      assert_equal "http://local.yahoo.com/details?id=21537477&stx=peets&csz=Mill+Valley+CA&ed=zgkiWa160Sy5r_v91d3HmvKuNMqhPzblP0CvIc2AKJjZ9ZGKEmfyqRaaOuNvb0zG57ejfwYjzW9vsQQ-", res2.yahoo_url


      #MGS- make another search with a location and not a zipcode
      results = simple_local_search("taco bell", "6160 Park Ave, Memphis, TN")
      assert_equal 20, results.length

      res1 = results[0]
      assert_equal "Taco Bell", res1.name
      assert_equal "1279 Ridgeway Rd", res1.address
      assert_equal "Memphis", res1.city
      assert_equal "TN", res1.state
      assert_equal "http://www.tacobell.com/", res1.url
      assert_equal "http://local.yahoo.com/details?id=15070367&stx=taco+bell&csz=Memphis+TN&ed=OzQZrq160SxBXqzU8BcDVCQ4KBE5y8snU4cnvmgbOhuNOAvvvovwavzZ7.tyyS5WO3QIlUkCGg--", res1.yahoo_url
    end
  end

end
