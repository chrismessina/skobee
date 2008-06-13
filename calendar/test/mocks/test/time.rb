require 'time'

class Time 
  @@advance_by_days = 0
  cattr_accessor :advance_by_days

  
  #MES- This is some super-funky stuff to test times and timezones.  To
  # properly test timezones, we need to test at times that are affected by
  # daylight savings time (e.g. to see that DST doesn't screw up our
  # local to UTC conversions, etc.)  But we can't count on tests being run
  # on days that are near a DST switchover, so we need to fake out the test-
  # to pretend that we're running at one of those times.  These functions
  # let the caller set what is considered "now" by the Time class, which cascades
  # to other Time functions.
  @@now_arr = nil

  def self.set_now_gmt(y, m = 1, d = 1, h = 0, mi = 0, s = 0)
    @@now_arr = [y, m, d, h, mi, s]
    if block_given?
      begin
        yield
      ensure
        clear_now_gmt
      end
    end
  end

  def self.clear_now_gmt
    @@now_arr = nil
  end
  
  def self.set_advance_by_days(days)
    @@advance_by_days = days
    if block_given?
      begin
        yield
      ensure
        @@advance_by_days = 0
      end
    end
  end
  
  
  #MES- OK, this is kinda complicated.  I wrote code to set what's considered
  # 'now' (see the comment above.)  However, the Salted Login test code modifies
  # 'now' in a different manner- they use an offset, whereas my code sets an
  # absolute time.  I've merged these approaches into the 'now' method.  If there's
  # an offset, it's used.  If there's no offset, but there's an absolute date, it's used.
  # If neither tweak is set up, the current time is used.
  def self.now
    if Time.advance_by_days != 0
      return Time.at(new.to_i + Time.advance_by_days * 60 * 60 * 24 + 1)
    elsif !@@now_arr.nil?
      self.utc @@now_arr[0], @@now_arr[1], @@now_arr[2], @@now_arr[3], @@now_arr[4], @@now_arr[5]
    else
      new
    end
  end
  
end