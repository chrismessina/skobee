require File.dirname(__FILE__) + '/../test_helper'


class PlaceTest_Simple < Test::Unit::TestCase

  def test_create_strips_whitespace
    place = Place.new
    place.name = "   blah       "
    assert_not_equal "blah", place.name

    place.save!

    assert_equal "blah", place.name
    assert_equal "blah", place.normalized_name
    assert_equal "blah", Place.find(place.id).name
    assert_equal "blah", Place.find(place.id).normalized_name
  end

end

class PlaceTest_RequirePlaces < Test::Unit::TestCase
  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :places


  def test_fully_specified
    fully_specified_place = Place.find(6)
    assert fully_specified_place.fully_specified

    no_address_info_place = Place.find(1)
    assert !no_address_info_place.fully_specified

    blank_address_info_place = Place.find(2)
    assert !blank_address_info_place.fully_specified
  end

  def test_public_venue
    public_place = Place.find(15)
    assert public_place.public_venue

    private_place = Place.find(16)
    assert !private_place.public_venue

    #MGS- testing public requested flag
    place = Place.find(places(:another_place).id)
    assert !place.public_requested?

    place = Place.find(places(:requested_public_place).id)
    assert place.public_requested?
  end

  def test_set_location
    #MES- Get rid of any cache entries
    Place.connection.delete("TRUNCATE TABLE geocode_cache_entries")

    #MES- First, set Place to NOT geocode synchronously
    Place.geocode_synchronously = false

    #MES- This place is geocoded at the beginning of the test
    ven = places(:place_for_location_search)
    assert_equal Place::GEOCODE_GEOCODE_APPLIED, ven.geocoded

    #MES- After setting the address, it should no longer be geocoded
    ven.location = '4209 Howe st., 94611'
    assert_equal Place::GEOCODE_NOT_GEOCODED, ven.geocoded
    assert_nil ven.lat
    assert_nil ven.long


    #MES- Now do the same test, but geocode synchronously.
    Place.geocode_synchronously = true

    #MES- Since we'll be geocoding, set up some mocks so we don't actually hit the network
    mock_opens = {
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=4209+Howe+st.%2C+94611' => './test/mocks/resources/4209_howe_2.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=undecipherable' => './test/mocks/resources/undecipherable_yahoo.xml'
    }

    with_mock_opens(mock_opens) do
      #MES- Set the address, which should do the geocoding for the NEW address.
      ven.location = '4209 Howe st., 94611'
      assert_equal Place::GEOCODE_GEOCODE_APPLIED, ven.geocoded
      assert_equal(37.828595, ven.lat)  #MES- Value returned by yahoo
      assert_equal(-122.251363, ven.long)  #MES- Value returned by yahoo
    end
  end

  def test_set_url
    #MES- Not much here, we should be able to set and get the URL
    ven = places(:first_place)
    assert_nil ven.url

    ven.url = 'this is an url'
    ven.save
    ven = places(:first_place, :force)
    assert_equal 'this is an url', ven.url

    ven.url = nil
    ven.save
    ven = places(:first_place, :force)
    assert_nil ven.url
  end

  def test_set_phone
    #MES- Phone numbers should be normalized on save
    ven = places(:first_place)
    assert_nil ven.url

    ven.phone = '(510) 594-8511'
    if !ven.save
      ven.errors.each{|error| p error}
      assert false
    end
    ven = places(:first_place, :force)
    assert_equal '5105948511', ven.phone

    ven.phone = '1 (510) 594-8511'
    ven.save
    ven = places(:first_place, :force)
    assert_equal '5105948511', ven.phone

    ven.phone = '1.800.TES.ting'
    ven.save
    ven = places(:first_place, :force)
    assert_equal '8008378464', ven.phone

    ven.phone = nil
    ven.save
    ven = places(:first_place, :force)
    assert_nil ven.phone
  end

  def test_geocode_location
    #MES- Get rid of any cache entries
    Place.connection.delete("TRUNCATE TABLE geocode_cache_entries")

    #MES- Set up some mock opens, for performance.  Basically, when an HTTP request
    # is made for an URL, the request will be redirected to a local file.
    mock_opens = {
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=4209+Howe+st.%2C+94611' => './test/mocks/resources/4209_howe_2.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=undecipherable' => './test/mocks/resources/undecipherable_yahoo.xml'
    }

    with_mock_opens(mock_opens) do
      #MES- The first place has a legit address, but is not geocoded
      ven = places(:first_place)
      assert_equal '4209 Howe st., 94611', ven.location
      assert_nil ven.address
      assert_nil ven.city
      assert_nil ven.state
      assert_nil ven.zip
      assert_equal Place::GEOCODE_NOT_GEOCODED, ven.geocoded

      result = ven.geocode_location!
      ven.save
      assert result
      assert_equal('4209 Howe St', ven.address)
      assert_equal('Oakland', ven.city)
      assert_equal('CA', ven.state)
      assert_equal('94611-4704', ven.zip)
      assert_equal(37.828595, ven.lat)  #MES- Value returned by yahoo
      assert_equal(-122.251363, ven.long)  #MES- Value returned by yahoo
      assert_equal Place::GEOCODE_GEOCODE_APPLIED, ven.geocoded
      #MES- The location should not have been normalized
      assert_equal '4209 Howe st., 94611', ven.location


      #MES- The second place has an underspecified address- multiple
      # items match the string
      ven = places(:another_place)
      assert ven.lat.nil?
      assert ven.long.nil?
      assert_equal Place::GEOCODE_NOT_GEOCODED, ven.geocoded

#MES- Yahoo! returns a definitive location for this address, though geocoder.us does not.
# I haven't yet found an address for which Yahoo! returns multiple results.
#    result = ven.geocode_location!
#    ven.save
#    assert !result
#    assert ven.lat.nil?
#    assert ven.long.nil?
#    assert_equal Place::GEOCODE_GEOCODE_APPLIED, ven.geocoded

      #MES- The third place does not have a real address
      ven = places(:place_owned_by_bob)
      assert ven.lat.nil?
      assert ven.long.nil?
      assert_equal Place::GEOCODE_NOT_GEOCODED, ven.geocoded

      result = ven.geocode_location!
      ven.save
      assert !result
      assert ven.lat.nil?
      assert ven.long.nil?
      assert_equal Place::GEOCODE_GEOCODE_APPLIED, ven.geocoded
    end
  end
end

class PlaceTest_PlacesUsers < Test::Unit::TestCase
  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :places, :users

  def test_find_by_name_and_location_secure
    place = Place.find_by_name_and_location_secure('D4E484F04EBF4B41ABF39FC3416D97F3, search for abcde', nil, users(:bob))
    assert_equal places(:place_owned_by_bob), place
    place = Place.find_by_name_and_location_secure(nil, 'West 42nd & Broadway, New York, NY', users(:bob))
    assert_equal places(:another_place), place
    place = Place.find_by_name_and_location_secure('D4E484F04EBF4B41ABF39FC3416D97F3, search for abcde', 'West 42nd & Broadway, New York, NY', users(:bob))
    assert_nil place
    place = Place.find_by_name_and_location_secure('E37B08B1454846E8A1895F5C6E03F22F, search', 'West 42nd & Broadway, New York, NY', users(:bob))
    assert_equal places(:another_place), place

    #MES- Test that only places that match the metro of the user are returned.
    # deletebob2 has a metro (bob does not)
    place = Place.find_by_name_and_location_secure('2F21F2C994EE48908B4704550961E7A7, search', nil, users(:deletebob2))
    assert_nil place
    place = Place.find_by_name_and_location_secure('Pho So', nil, users(:deletebob2))
    assert_equal places(:seattle_restaurant1), place

  end

  def test_find_or_create_by_name_and_location
    place, created = Place.find_or_create_by_name_and_location('D4E484F04EBF4B41ABF39FC3416D97F3, search for abcde', nil, users(:bob))
    assert_equal places(:place_owned_by_bob), place
    assert !created
    place, created = Place.find_or_create_by_name_and_location(nil, 'West 42nd & Broadway, New York, NY', users(:bob))
    assert_equal places(:another_place), place
    assert !created
    place, created = Place.find_or_create_by_name_and_location('E37B08B1454846E8A1895F5C6E03F22F, search', 'West 42nd & Broadway, New York, NY', users(:bob))
    assert_equal places(:another_place), place
    assert !created

    #MES- If a search is a "miss", a new place should be created
    place, created = Place.find_or_create_by_name_and_location('D4E484F04EBF4B41ABF39FC3416D97F3, search for abcde', 'West 42nd & Broadway, New York, NY', users(:bob))
    assert_not_nil place
    assert created
    assert place.id > places(:seattle_restaurant_owned_by_x_dummy_user_4).id
  end

  def test_comments
    ven = places(:first_place)

    #MGS- create comment
    comment = Comment.new()
    comment.body = "This is a test place comment."
    comment.owner_id = users(:user_with_friends).id
    comment.save
    ven.comments << comment

    assert_equal 1, ven.comments.length
    assert_kind_of Comment, ven.comments[0]

    #MGS- try to delete comment as a non-owner
    assert_raise(RuntimeError) { comment.delete_from_collection(users(:user_with_contacts), ven.comments) }

    #MGS- delete comment with legit user
    comment.delete_from_collection(users(:user_with_friends), ven.comments)
    assert ven.comments.length == 0
  end

  def test_find_user_random_places
    #KS- how many random places does user 1 have? should be 0
    user1 = users(:bob)
    assert_equal 0, Place.find_user_random_places(user1).length

    #KS- user 2 should have 2 places (a bunch of their plans are at the same place, nil, or private)
    user2 = users(:existingbob)
    assert_equal 2, Place.find_user_random_places(user2).length
  end

  def test_find_word_break_match
    res = Place.find_word_break_match(users(:bob), 'China Ca')
    #MES- There should be two places that match- both called "China Cafe".  Other
    # places with China in the name (e.g. 'china bistro chinese restaurant') should
    # NOT match
    assert_equal 2, res.length

    #MES- Full names should also match, and string should be normalized
    assert_equal 1, Place.find_word_break_match(users(:bob), 'hana zE\'n').length

    #KS: geocode the first couple places so we can use them in our proximity search tests

    mock_opens = {
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=4209+Howe+st.%2C+94611' => './test/mocks/resources/4209_howe_2.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=West+42nd+%26+Broadway%2C+New+York%2C+NY' => './test/mocks/resources/w_42nd_and_broadway.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=12165+Alta+Carmel+Court%2C+san+diego%2C+ca' => './test/mocks/resources/12165_alta_carmel.xml'
    }
    with_mock_opens(mock_opens) do
      ven = places(:first_place)
      ven.geocode_location!
      ven.save
      ven = places(:another_place)
      ven.geocode_location!
      ven.save

      #KS: find places by proximity and text
      vens = Place.find_word_break_match(users(:bob), 'China Ca', '12165 Alta Carmel Court, san diego, ca', 10)
      assert_equal 1, vens.length
      assert vens.include?(places(:san_diego_restaurant3))

      #MES- The searches should respect security
      assert_equal 1, Place.find_word_break_match(users(:bob), 'D4E484F04').length
      assert_equal 1, Place.find_word_break_match(users(:longbob), 'D4E484F04').length
      assert_equal 2, Place.find_word_break_match(users(:user_with_friends_and_friends_cal), 'D4E484F04').length
    end
  end
end

class PlaceTest < Test::Unit::TestCase

  #MES- The places table is based on the MYISAM storage option, rather than InnoDB, so it
  # doesn't support transactions.
  self.use_transactional_fixtures = false

  fixtures :places, :users, :plans, :planners, :planners_plans, :user_contacts, :geocode_cache_entries, :place_popularity_stats


  def test_find_popular_by_day
    #KS- get essentially any place with place popularity data on it that is within user 1's bounding box
    popular_places = Place.find_popular_by_day(users(:bob))

    #KS- user 1 should see 8 popular places
    assert_equal 8, popular_places.length

    #KS- make sure the ranking is in the correct order
    assert_equal 4, popular_places[0].id
    assert_equal 7, popular_places[1].id
    assert_equal 10, popular_places[2].id
    assert_equal 8, popular_places[3].id
    assert_equal 11, popular_places[4].id
    assert_equal 5, popular_places[5].id
    assert_equal 9, popular_places[6].id
    assert_equal 6, popular_places[7].id

    #KS- make sure there are no duplicates
    id_array = []
    popular_places.each{|place|
      id_array << place.id
    }
    assert_equal 8, id_array.uniq.length

    #KS- make sure it only returns stuff where popularity data exists for within the date range
    date_restricted_popular_places = Place.find_popular_by_day(users(:bob), Time.now + 1.days, Time.now + 1.years, 1000)
    assert_equal 6, date_restricted_popular_places.length

    #KS- make sure user can only see stuff within their bounding box
    user_23_popular_places = Place.find_popular_by_day(users(:x_dummy_user_7), Time.now - 1.years, Time.now + 1.years, 1000)
    assert_equal 2, user_23_popular_places.length
  end

  def test_recent_friend_places
    places = Place.find_recent_friend_places(users(:user_with_friends))

    #MES- There should be three items in the array
    assert_equal 4, places.length, 'Array of recent friend places should contain 3 items'
    assert_equal places(:place_owned_by_bob), places[0]
    assert_equal places(:superfluous_place), places[1]
    assert_equal places(:another_place), places[2]
    assert_equal places(:first_place), places[3]

    #MES- Try asking for only one item
    places = Place.find_recent_friend_places(users(:user_with_friends), 1)

    #MES- There should be one item in the array
    assert_equal 1, places.length, 'Array of recent friend places should contain 1 item'
    assert_equal places(:place_owned_by_bob), places[0]
  end

  def test_recent_user_places
    places = Place.find_user_recent_places(users(:user_with_friends))

    #KS- there should be one place in the array
    assert_equal 1, places.length, 'Array of recent user places should contain 1 item'
    #KS- the place should be :first_place, where :user_with_friends_plan was hosted
    assert_equal places(:first_place), places[0], 'Item 0 in recent user place not the correct item'
  end

  def test_search
    #MES- We need the place statistics data to be in there, for place search by time to work
    Place.update_usage_stats

    #MES- Test searching by name (full text)- should ignore punctuation and case
    vens = Place.find_by_ft_search(users(:bob), 'Sear$ch a!bcd', true)
    assert_equal 4, vens.length
    assert vens.include?(places(:place_to_search_for))
    assert vens.include?(places(:place_owned_by_bob))

    #MES- FT search should respect security
    vens = Place.find_by_ft_search(users(:longbob), 'abcde', true)
    assert_equal 2, vens.length
    assert_equal places(:place_owned_by_bob), vens[0]
    assert_equal places(:place_to_search_for), vens[1]

    #KS- try it with the owner of the guy who owns place 18
    vens = Place.find_by_ft_search(users(:user_with_friends_and_friends_cal), 'abcde', true)
    assert_equal 3, vens.length
    assert_equal places(:place_owned_by_user_with_friends_and_friends_cal), vens[0]
    assert_equal places(:place_owned_by_bob), vens[1]
    assert_equal places(:place_to_search_for), vens[2]

    #MES- Test searching by time
    tz = TZInfo::Timezone.get('America/Tijuana')
    target_time = tz.utc_to_local(Time.utc(Time.now.year + 1, 6, 6, 13, 0, 0, 0))
    target_day = target_time.wday

    #KS: set up mock opens for locations we will be using as sources
    mock_opens = {
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=4209+Howe+St%2C+Oakland%2C+CA%2C+94611' => './test/mocks/resources/4209_howe_complete.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=12165+Alta+Carmel+Court%2C+san+diego%2C+ca' => './test/mocks/resources/12165_alta_carmel.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=1048+S+Jackson+St%2C+seattle%2C+wa' => './test/mocks/resources/1048_s_jackson.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=4209+Howe+st.%2C+94611' => './test/mocks/resources/4209_howe_2.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=West+42nd+%26+Broadway%2C+New+York%2C+NY' => './test/mocks/resources/w_42nd_and_broadway.xml',
      'http://api.local.yahoo.com/MapsService/V1/geocode?appid=just_to_test&location=4210+Howe+st.%2C+94611' => './test/mocks/resources/4210_howe_2.xml',
    }
    with_mock_opens(mock_opens) do
      #KS: geocode the first couple places so we can use them in our proximity search tests
      ven = places(:first_place)
      ven.geocode_location!
      ven.save
      ven = places(:another_place)
      ven.geocode_location!
      ven.save

      #KS: find places by proximity and text
      vens = Place.find_by_name_prox_time(users(:bob), 'chinese', '12165 Alta Carmel Court, san diego, ca', 10, nil, nil, nil, nil, false)
      assert_equal 2, vens.length, "vens.length is #{vens.length}"
      assert vens.include?(places(:san_diego_restaurant1))
      assert vens.include?(places(:san_diego_restaurant2))

      #KS: find places by proximity and time
      vens = Place.find_by_name_prox_time(users(:bob), nil, '4210 Howe st., 94611', 1, tz, target_day, target_time, 90, true)
      assert_equal 1, vens.length
      assert vens.include?(places(:first_place))

      #KS: find places by text and time
      vens = Place.find_by_name_prox_time(users(:bob), '2F21F2C994EE48908B4704550961E7A7', nil, nil, tz, target_day, target_time, 90, true)
      assert vens.length == 1, "vens.length is #{vens.length}"
      assert vens.include?(places(:first_place))

      #KS: find places by text, proximity, and time
      vens = Place.find_by_name_prox_time(users(:bob), '2F21F2C994EE48908B4704550961E7A7', '4210 Howe st., 94611', 1, tz, target_day, target_time, 90, true)
      assert vens.length == 1, "vens.length is #{vens.length}"
      assert vens.include?(places(:first_place))

      #MES- The user "existingbob" is in a metro that should NOT get a hit for chinese restaurants
      vens = Place.find_by_name_prox_time(users(:existingbob), 'chinese', nil, nil, nil, nil, nil, nil, true)
      assert_equal 0, vens.length, "vens.length is #{vens.length}"

      #MES- But when exisingbob searches with a specific address, he should see the same places
      vens = Place.find_by_name_prox_time(users(:existingbob), 'chinese', '12165 Alta Carmel Court, san diego, ca', 10, nil, nil, nil, nil, true)
      assert_equal 2, vens.length, "vens.length is #{vens.length}"
      assert vens.include?(places(:san_diego_restaurant1))
      assert vens.include?(places(:san_diego_restaurant2))
    end



    #MES- When you change the name of a place, the search should update
    ven = places(:place_to_search_for, :force)
    ven.name = 'Here\'s some tr$ick*y stuff t0 search for'
    ven.save

    #MES- Test searching by name (full text)- should ignore punctuation and case
    vens = Place.find_by_ft_search(users(:bob), 'tricky stuff', true)
    assert_equal 1, vens.length
    assert vens.include?(places(:place_to_search_for))
  end

#  def test_plan_cache
#    #MES- There shouldn't be any cache entries when we start the test
#    assert_equal 0, Place.connection.select_all('SELECT COUNT(*) AS ct FROM place_plans_cache')[0]['ct'].to_i
#
#    #MES- If we create a plan, and set the place,
#    #  an entry should be made in the cache
#    pln = Plan.new
#    place = places(:first_place)
#    pln.place = place
#    pln.save
#
#    assert_equal 1, Place.connection.select_all('SELECT COUNT(*) AS ct FROM place_plans_cache')[0]['ct'].to_i
#    assert_equal pln.id, Place.connection.select_all("SELECT plan_id FROM place_plans_cache WHERE place_id = #{place.id}")[0]['plan_id'].to_i
#
#  end
end

#########################################################################################
#KS- Tests of places and planners_plans
#########################################################################################

class PlaceTest_Planners_PlansAndPlaces < Test::Unit::TestCase

  fixtures :users, :planners_plans, :places

  def test_user_places
    assert_equal places(:first_place).id, Place.find_user_places(users(:longbob))[0].id
    assert places(:private_vlue), Place.find_user_places(users(:longbob).id)[1].id

    assert_equal 2, Place.find_user_places(users(:user_with_friends)).length
    assert_equal places(:first_place).id, Place.find_user_places(users(:user_with_friends).id)[0].id
    assert_equal places(:another_place).id, Place.find_user_places(users(:user_with_friends))[1].id

    assert_equal 2, Place.find_user_places(users(:friend_1_of_user).id).length
    assert_equal places(:first_place).id, Place.find_user_places(users(:friend_1_of_user))[0].id
    assert_equal places(:another_place).id, Place.find_user_places(users(:friend_1_of_user).id)[1].id
  end

end
