class Date
  #MES- The day of the week that Skobee considers the "beginning" of the week
  WEEK_START_DAY = 1  #MES- Monday.
  
  #MES- "Today" in the timezone indicated
  def self.today_tz(timezone)
    timezone.now.to_date
  end

  def zero_day_of_week
    self - self.wday
  end
  
  def last_day_of_week
    self + (6 - self.wday)
  end

  #MGS- take a ruby date and return a string that constructs a javascript date object
  # This is equivalent to the sk_time function, except it only sets the date, not the time
  # The javascript month is 0 indexed as opposed to the ruby Date which is 1 indexed
  # 4 = May in javascript and April in ruby
  def to_javascript_string
    return "new Date(#{self.year},#{self.mon-1},#{self.day},0,0,0,0)"
  end

  def beginning_of_week
    #MES- Skobee considers day WEEK_START_DAY to be the first day of the week, but
    # Ruby sets day 0 to Sunday. We have to compensate.
    self - ((self.wday - WEEK_START_DAY) % 7)
  end

  def beginning_of_month
    self - (self.mday - 1)
  end

  def next_month_start
    new = self>>(1)
    new - (new.mday - 1)
  end

  def end_of_month
    new = self>>(1)
    new - new.mday
  end

  def next_weekday(day)
    #MES- Weekday is a number indicating the day of the week (e.g.
    # 0 == sunday, 1 == monday, etc.)
    # This function returns a Date that chooses the next occurrence
    # of the indicated day.  For example, if this object is Monday the 3rd and
    # you pass in 2, you'll get Tuesday the 4th.  It will never return
    # the current day (e.g. if this object is Monday the 3rd and you
    # pass in 1, you'll get Monday the 10th.)

    #MES- Do we want the one in THIS week, or the one in the NEXT week?
    if day > self.wday
      #MES- In this week
      return self.zero_day_of_week + day
    else
      #MES- Next week
      return self.zero_day_of_week + (7 + day)
    end
  end

  def to_numeric_arr
    [self.year, self.mon, self.day]
  end

  #MES- This seems to help performance a tiny bit, but not much
#  def <=> (other)
#    case other
#    when Numeric; return @ajd <=> other
#    #when Date;    return @ajd <=> other.ajd
#    when Date
#      ajd_float = @ajd.to_f
#      other_ajd_float = other.ajd.to_f
#      if 0.1 < (ajd_float - other_ajd_float).abs
#        return ajd_float <=> other_ajd_float
#      end
#      return @ajd <=> other.ajd
#    end
#    nil
#  end
  #MES- Here's what the original looked like:
#  def <=> (other)
#    case other
#    when Numeric; return @ajd <=> other
#    when Date;    return @ajd <=> other.ajd
#    end
#    nil
#  end

  #MES- This seems to help performance a bit.  The
#  HALF_AS_RAT = 1.to_r/2
#  def self.ajd_to_jd(ajd, of=0) clfloor(ajd + of + HALF_AS_RAT) end
  #MES- Here's what the original looked like:
  #def self.ajd_to_jd(ajd, of=0) clfloor(ajd + of + 1.to_r/2) end
end