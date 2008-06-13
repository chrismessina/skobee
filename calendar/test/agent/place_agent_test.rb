require File.dirname(__FILE__) + '/../test_helper'

class PlaceAgentTest < Test::Unit::TestCase
  fixtures :places, :plans, :planners_plans, :place_usage_stats, :place_popularity_stats, :users

  def setup
  end

  def test_perform_geocoding
    num_geocoded_start = Place.count "geocoded = #{Place::GEOCODE_NOT_GEOCODED}"

    Place.perform_geocoding(1, 0)

    num_geocoded_end = Place.count "geocoded = #{Place::GEOCODE_NOT_GEOCODED}"
    assert_equal num_geocoded_start - 1, num_geocoded_end, 'Wrong number of items geocoded'

    #MES- Geocode the remaining items
    Place.perform_geocoding

    #MES- The items should be geocoded, INCLUDING items
    # for which the lookup failed.
    assert_equal Place::GEOCODE_GEOCODE_APPLIED, Place.find(places(:first_place).id).geocoded, 'First place not geocoded'
    assert_equal Place::GEOCODE_GEOCODE_APPLIED, Place.find(places(:another_place).id).geocoded, 'Another place not geocoded'
    assert_equal Place::GEOCODE_GEOCODE_APPLIED, Place.find(places(:place_owned_by_bob).id).geocoded, 'place_owned_by_bob not geocoded'
  end

  def test_update_usage_stats
    #MES- Make sure there are no stats before we start testing
    assert_equal 0, Place.connection.select_all('SELECT COUNT(*) AS ct FROM place_usage_stats')[0]['ct'].to_i

    #MES- Run the agent
    Place.update_usage_stats

    tz = TZInfo::Timezone.get('America/Tijuana')
    target_time = tz.utc_to_local(Time.utc(Time.now.year + 1, 6, 6, 13, 0, 0, 0))
    target_day = target_time.wday

    stats_for_ven_one = <<-END_OF_STRING
      SELECT
        *
      FROM
        place_usage_stats
      WHERE
        place_id = 1 AND
        day = #{target_day}
      ORDER BY
        hour ASC
    END_OF_STRING

    #MES- There should be two rows, one for hour 6 and one for hour 7.  The num_plans should be 1, and the num_user_plans should be 2
    stats = Place.connection.select_all(stats_for_ven_one)
    assert !stats.nil?
    assert_equal 2, stats.length
    assert_equal 6, stats[0]['hour'].to_i
    assert_equal 1, stats[0]['num_plans'].to_i
    assert_equal 2, stats[0]['num_user_plans'].to_i
    assert_equal 7, stats[1]['hour'].to_i
    assert_equal 1, stats[1]['num_plans'].to_i
    assert_equal 2, stats[1]['num_user_plans'].to_i

  end

  def test_update_popularity_stats
    #MES- Make sure there are no stats before we start testing
    delete_place_popularity_sql = "TRUNCATE TABLE place_popularity_stats"
    Place.perform_delete_sql([delete_place_popularity_sql])
    assert_equal 0, Place.connection.select_all('SELECT COUNT(*) AS ct FROM place_popularity_stats')[0]['ct'].to_i

    #MES- Run the agent
    Place.update_popularity_stats

    #MES- With the data in the test system, place_popularity_stats should have one row, for place_owned_by_bob
    pop_places = Place.find_popular_by_day(users(:user_with_friends))
    assert_equal 1, pop_places.length
    assert_equal places(:place_owned_by_bob), pop_places[0]

    #MES- user_with_friends doesn't have a bounding box, but existingbob does, so if existingbob
    # looks, he shouldn't see the place (since it's outside of his bounding box.)
    pop_places = Place.find_popular_by_day(users(:existingbob))
    assert_equal 0, pop_places.length
  end

end