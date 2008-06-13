require File.dirname(__FILE__) + '/../test_helper'

class ApplicationTest < Test::Unit::TestCase

  def test_string_is_email
    assert "scrub@scrub.com".is_email?
    assert !"@scrub.com".is_email?
    assert !"scrub@.com".is_email?
    assert !"scrub@scrub.".is_email?
    assert !"scrub@scrubcom".is_email?
    assert !"scrub@".is_email?
    assert !"@scrub.com".is_email?
    assert !"@.".is_email?
    assert !"@".is_email?
    assert "s@sc.com".is_email?
    assert "s@s.uk".is_email?
    assert "s+1@sc.uk".is_email?
    assert "s+1@s.uk".is_email?
    assert "bsd@bSd.cO.uk".is_email?
    assert "jj@ff.com".is_email?
    assert !"dsdsfdsf@zdfgfd.com\r\ndfgsdgds@dgdgdsg.com".is_email?
    assert !"dsgdsgdsg@dsgdsg.com\r\ndfegdsgds@dgdsg.com\r\ndsgSDGSDYGDSG@dgdgdSGSDGDS.com".is_email?
    assert !"dsgdsgdsg@dsgdsg.com dfegdsgds@dgdsg.com dsgSDGSDYGDSG@dgdgdSGSDGDS.com".is_email?
  end

  def test_split_emails
    email_list = "test@test.com, test3@test.com; ; ; ; ; ; , , , ;test4@test.com; test5@test.com \r\n   "
    emails = email_list.split_delimited_emails()
    assert_equal 4, emails.length
    assert_equal "test@test.com", emails[0]
    assert_equal "test3@test.com", emails[1]
    assert_equal "test4@test.com", emails[2]
    assert_equal "test5@test.com", emails[3]

    email_list = "test@test.com;       test3@test.com ;test4@test.com, test5@test.com"
    emails = email_list.split_delimited_emails()
    assert_equal 4, emails.length
    assert_equal "test@test.com", emails[0]
    assert_equal "test3@test.com", emails[1]
    assert_equal "test4@test.com", emails[2]
    assert_equal "test5@test.com", emails[3]

    email_list = "          test@test.com, test3@test.com; \r\n test4@test.com, test5@test.com         "
    emails = email_list.split_delimited_emails()
    assert_equal 4, emails.length
    assert_equal "test@test.com", emails[0]
    assert_equal "test3@test.com", emails[1]
    assert_equal "test4@test.com", emails[2]
    assert_equal "test5@test.com", emails[3]

    email_list = "           \"test at test dot com\" <test@test.com>, test3@test.com; \r\n test4@test.com, test five <test5@test.com>         "
    emails = email_list.split_delimited_emails()
    assert_equal 4, emails.length
    assert_equal "test@test.com", emails[0]
    assert_equal "test3@test.com", emails[1]
    assert_equal "test4@test.com", emails[2]
    assert_equal "test5@test.com", emails[3]

    email_list = "           test@test.com, \"test three\" <test3@test.com>; \r\n test4@test.com, test5@test.com         "
    emails = email_list.split_delimited_emails()
    assert_equal 4, emails.length
    assert_equal "test@test.com", emails[0]
    assert_equal "test3@test.com", emails[1]
    assert_equal "test4@test.com", emails[2]
    assert_equal "test5@test.com", emails[3]
  end

  def test_date
    dt = Date.civil(2005, 11, 30) # a Wednesday
    assert_equal Date.civil(2005, 11, 27), dt.zero_day_of_week
    assert_equal Date.civil(2005, 12, 3), dt.last_day_of_week
    assert_equal Date.civil(2005, 11, 28), dt.beginning_of_week
    assert_equal Date.civil(2005, 11, 1), dt.beginning_of_month
    assert_equal Date.civil(2005, 12, 1), dt.next_month_start
    assert_equal Date.civil(2005, 12, 1), dt.next_weekday(4)
    assert_equal Date.civil(2005, 12, 7), dt.next_weekday(3)
    assert_equal 'new Date(2005,10,30,0,0,0,0)', dt.to_javascript_string
    dt = Date.civil(2005, 11, 27) # a Sunday
    assert_equal Date.civil(2005, 11, 27), dt.zero_day_of_week
    assert_equal Date.civil(2005, 12, 3), dt.last_day_of_week
    assert_equal Date.civil(2005, 11, 21), dt.beginning_of_week

  end

  def test_time
    tm = Time.utc(2005, 11, 30, 5, 35, 1)
    assert_equal '2005-11-30', tm.to_date_s
    assert_equal 'new Date(2005,10,30,5,35,1,0)', tm.to_javascript_string
    assert_equal Date.civil(2005, 11, 30), tm.to_date
    assert_equal [2005, 11, 30], tm.to_numeric_date_arr
    assert_equal [5,35,1], tm.to_numeric_time_arr

    #MES- Test the Time::correct_hour_for_meridian(hour, meridian)
    assert_equal 0, Time::correct_hour_for_meridian(12, 'Am')
    assert_equal 12, Time::correct_hour_for_meridian(12, 'pM')
    assert_equal 13, Time::correct_hour_for_meridian(1, 'pM')

    #MES- Test the day_begin function
    assert_equal 0, Time.now.day_begin.hour
    assert_equal 0, Time.now.day_begin.min
    assert_equal 0, Time.now.day_begin.sec
  end
  
  def test_string_contains_int
    assert '123'.contains_int?
    assert '0'.contains_int?
    assert '1234567890123456789012345678901234567890'.contains_int?
    assert !'1.23'.contains_int?
    assert !'-123'.contains_int?
    assert !'123test'.contains_int?
    assert !'test'.contains_int?
    assert !''.contains_int?
    assert !'1234567890123456789012345678901234567890 test 1234567890123456789012345678901234567890'.contains_int?
  end
  
end