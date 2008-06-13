class Time
  #Convert the date to a string in YYYY-MM-DD format
  def to_date_s
    "#{year}-#{mon}-#{mday}"
  end

  #MGS- take a ruby time and return a string that constructs a javascript date object
  # The javascript month is 0 indexed as opposed to the ruby Date which is 1 indexed
  # 4 = May in javascript and April in ruby
  def to_javascript_string
    return "new Date(#{self.year},#{self.mon-1},#{self.day},#{self.hour},#{self.min},#{self.sec},0)"
  end

  #KS- pass in a utc time and a timezone, and this will spit back the utc time
  #of the beginning of the day (12:01 AM) in the given timezone
  def self.get_day_begin(timezone)
    local_time = timezone.utc_to_local(now_utc)
    begin_of_day = local_time - local_time.hour.hours - local_time.min.minutes + 1.minutes
  end

  #KS- get the current time in utc
  def self.now_utc
    now = Time.new
    if now.utc?
      return now
    else
      return now.utc
    end
  end

  def to_date
    Date::civil(self.year, self.mon, self.day)
  end
  
  #MES- Get the beginning of day for this time, in whatever timezone we're in
  def day_begin
    self - ((self.hour * 3600) + (self.min * 60) + self.sec)
  end

  def to_numeric_date_arr
    [self.year, self.mon, self.day]
  end

  def to_numeric_time_arr
    [self.hour, self.min, self.sec]
  end

  #MES- Returns the value of _time_ as an integer number of days since
  # epoch.
  def tv_day
    tv_sec/(60*60*24)
  end
  
  #MES- Return the hour of the time for a twelve hour clock (e.g.
  # 3 PM would return 3, rather than 15
  def hour_12
    hr = self.hour
    #MES- Hours over 12 are PM, subtract 12
    hr = hr - 12 if hr > 12
    #MES- But the zeroth hour is called 12 (midnight is called hour 12.)
    hr = 12 if hr == 0
    return hr
  end

  def self.correct_hour_for_meridian(hour, meridian)
    #MES- Take in an hour and a meridian indicator, and
    # add to the hour if needed to convert to 24 hour time.
    # For instance, arguments 8 and 'am' would return 8, but
    # arguments 1 and 'pm' would return 13.
    # As a special case, 12 and 'am' returns 0

    #MES- 12 means zero- 12 AM is the beginning of the day, and 12 PM is 12 AM
    # (i.e. zero) plus 12 hours for the meridian
    hour = 0 if 12 == hour
    #MES- Fix the hour for AM/PM
    if !meridian.nil?
      hour += 12 if 'pm' == meridian.downcase
    end

    return hour
  end

  def fmt_for_mysql
    #MES- Convert a Time to the format expected in fixtures
    self.strftime('%Y-%m-%d %H:%M:%S')
  end
  
  def fmt_date_for_mysql
    #MES- Convert a Time to the format expected by MySQL (and Flickr, among others) for the date
    self.strftime('%Y-%m-%d')
  end
  
  #MES- Returns a boolean indicating if the passed in time is within
  # allowed_seconds_diff of this time
  def near?(other, allowed_seconds_diff = 30)
    allowed_seconds_diff = allowed_seconds_diff.abs
    diff = (self - other).abs
    return (diff <= allowed_seconds_diff)
  end

######################################################################################
####  Helper functions used by fixtures
######################################################################################

  def self.now_for_mysql
    return Time.now.utc.fmt_for_mysql
  end

  def self.fuzzy_datetime_for_fixture(days_offset, fuzzy_time)
    #MES- Create a datetime (i.e. a Time object) for the fixtures.
    # days_offset is the offset from today (e.g. 1 means tomorrow), and
    # fuzzy_time is one of the Plan::TIME_DESCRIPTION constants
    dt = Date.today + days_offset.to_i
    tm_info = Plan::TIME_DESC_TO_TIME_MAP[fuzzy_time]
    return Time.local(dt.year, dt.mon, dt.day, tm_info[0], tm_info[1])
  end

  def self.exact_datetime_for_fixture(days_offset, hour, min = 0)
    #MES- Create a datetime (i.e. a Time object) for the fixtures.
    # days_offset is the offset from today (e.g. 1 means tomorrow)
    dt = Date.today + days_offset.to_i
    return Time.local(dt.year, dt.mon, dt.day, hour, min)
  end

  def self.offset_next_week()
    (7 - Date.today.wday) + 1
  end

  def self.offset_this_week()
    1 - Date.today.wday
  end
end