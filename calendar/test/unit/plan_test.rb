require File.dirname(__FILE__) + '/../test_helper'

#########################################################################################
#MES- Tests that do not depend on fixtures
#########################################################################################

class PlanTest_NoFixtures < Test::Unit::TestCase


  def test_comparison
    #MES- Sort should be by:
    # fuzzy start date (no time)
    # duration of fuzzy period (i.e. fuzzy_start - start)
    # start datetime
    # created datetime

    #MES- Test comparing two plans using <=>
    start_date = Time.utc(2005, 6, 1, 20, 0, 0)
    pln1 = Plan.new
    pln1.name, pln1.start, pln1.fuzzy_start, pln1.duration = 'A', start_date, start_date, 60
    pln1.save
    sleep(1.1)
    pln2 = Plan.new
    pln2.name, pln2.start, pln2.fuzzy_start, pln2.duration = 'A', start_date, start_date, 60
    pln2.save

    #MES- Sort by ID
    assert_equal(-1, (pln1 <=> pln2), '<=> should return the younger plan for othewise equivalent plans')
    plns = [pln1, pln2]
    plns.sort!
    assert_equal pln1, plns[0], 'Sort of plans based on created_at failed'

    #MES- Sort by name
    pln1.name = 'B'
    plns.sort!
    assert_equal pln2, plns[0], 'Sort of plans based on name failed'

    #MES- Sort by start datetime
    pln1.start = Time.utc(2005, 6, 15, 19, 0, 0)
    pln1.fuzzy_start = Time.utc(2005, 6, 16, 19, 0, 0)
    pln2.start = Time.utc(2005, 6, 15, 20, 0, 0)
    pln2.fuzzy_start = Time.utc(2005, 6, 16, 20, 0, 0)
    plns.sort!
    assert_equal pln1, plns[0], 'Sort of plans based on start failed'

    #MES- Sort by fuzzy period (diff between start and fuzzy_start
    pln1.start = Time.utc(2005, 6, 15, 19, 0, 0)
    pln1.fuzzy_start = Time.utc(2005, 6, 16, 20, 0, 0)
    pln2.start = Time.utc(2005, 6, 15, 20, 0, 0)
    pln2.fuzzy_start = Time.utc(2005, 6, 16, 20, 0, 0)
    plns.sort!
    assert_equal pln2, plns[0], 'Sort of plans based on fuzzy period length failed'

    #MES- Sort by fuzzy_start day
    pln1.start = Time.utc(2005, 6, 15, 20, 0, 0)
    pln1.fuzzy_start = Time.utc(2005, 6, 16, 20, 0, 0)
    pln2.start = Time.utc(2005, 6, 15, 20, 0, 0)
    pln2.fuzzy_start = Time.utc(2005, 6, 17, 20, 0, 0)
    plns.sort!
    assert_equal pln1, plns[0], 'Sort of plans based on fuzzy_start date failed'
  end
  
  def test_set_datetime_no_timezone
    #MES- Test the set_datetime function, but don't worry about timezones and
    # Daylight Savings Time complexities.  Leave that to the test_timezone_handling.

    pln = Plan.new
    #MES- Note: Tijuana is GMT + 8 during non DST times.
    tz = TZInfo::Timezone.get('America/Tijuana')

    Time.set_now_gmt(2005, 12, 14, 12, 0, 0) do
      pln.set_datetime tz, Plan::DATE_DESCRIPTION_TODAY, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 14, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 12, 14, 17, 0, 0), pln.fuzzy_start
      assert_equal 9, pln.local_start.hour
      assert_equal Plan::DATE_DESCRIPTION_TODAY, pln.dateperiod(tz)

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_TOMORROW, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 15, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 12, 15, 17, 0, 0), pln.fuzzy_start
      assert_equal 9, pln.local_start.hour
      assert_equal Plan::DATE_DESCRIPTION_TOMORROW, pln.dateperiod(tz)

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_YESTERDAY, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 13, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 12, 13, 17, 0, 0), pln.fuzzy_start
      assert_equal 9, pln.local_start.hour
      assert_equal Plan::DATE_DESCRIPTION_YESTERDAY, pln.dateperiod(tz)

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_THIS_WEEK, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 12, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 12, 18, 17, 0, 0), pln.fuzzy_start
      assert_nil pln.local_start
      assert_equal Plan::DATE_DESCRIPTION_THIS_WEEK, pln.dateperiod(tz)

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_THIS_WEEKEND, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 17, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 12, 18, 17, 0, 0), pln.fuzzy_start
      assert_nil pln.local_start
      assert_equal Plan::DATE_DESCRIPTION_THIS_WEEKEND, pln.dateperiod(tz)

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_NEXT_WEEK, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 19, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 12, 25, 17, 0, 0), pln.fuzzy_start
      assert_nil pln.local_start
      assert_equal Plan::DATE_DESCRIPTION_NEXT_WEEK, pln.dateperiod(tz)

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_NEXT_WEEKEND, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 24, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 12, 25, 17, 0, 0), pln.fuzzy_start
      assert_nil pln.local_start
      assert_equal Plan::DATE_DESCRIPTION_NEXT_WEEKEND, pln.dateperiod(tz)

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_LAST_WEEK, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 5, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 12, 11, 17, 0, 0), pln.fuzzy_start
      assert_nil pln.local_start
      assert_equal Plan::DATE_DESCRIPTION_LAST_WEEK, pln.dateperiod(tz)

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_THIS_MONTH, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 1, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 12, 31, 17, 0, 0), pln.fuzzy_start
      assert_nil pln.local_start
      assert_equal Plan::DATE_DESCRIPTION_THIS_MONTH, pln.dateperiod(tz)

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_NEXT_MONTH, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2006, 1, 1, 17, 0, 0), pln.start
      assert_equal Time.utc(2006, 1, 31, 17, 0, 0), pln.fuzzy_start
      assert_nil pln.local_start
      assert_equal Plan::DATE_DESCRIPTION_NEXT_MONTH, pln.dateperiod(tz)

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_LAST_MONTH, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 11, 1, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 11, 30, 17, 0, 0), pln.fuzzy_start
      assert_nil pln.local_start
      assert_equal Plan::DATE_DESCRIPTION_LAST_MONTH, pln.dateperiod(tz)

      pln.set_datetime tz, [2005, 12, 14], Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 14, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 12, 14, 17, 0, 0), pln.fuzzy_start
      assert_equal 9, pln.local_start.hour

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_TODAY, Plan::TIME_DESCRIPTION_ALL_DAY
      assert_equal Time.utc(2005, 12, 14, 8, 0, 0), pln.start
      assert_equal 23*60 + 59, pln.duration
      assert_equal Plan::TIME_DESCRIPTION_ALL_DAY, pln.timeperiod
      assert_equal 0, pln.local_start.hour

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_TODAY, Plan::TIME_DESCRIPTION_EVENING
      assert_equal Time.utc(2005, 12, 15, 3, 0, 0), pln.start
      assert_equal 4*60 + 58, pln.duration
      assert_equal Plan::TIME_DESCRIPTION_EVENING, pln.timeperiod
      assert_equal 19, pln.local_start.hour

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_TODAY, Plan::TIME_DESCRIPTION_DINNER
      assert_equal Time.utc(2005, 12, 15, 2, 0, 0), pln.start
      assert_equal 3*60 + 30, pln.duration
      assert_equal Plan::TIME_DESCRIPTION_DINNER, pln.timeperiod
      assert_equal 18, pln.local_start.hour

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_TODAY, Plan::TIME_DESCRIPTION_AFTERNOON
      assert_equal Time.utc(2005, 12, 14, 22, 0, 0), pln.start
      assert_equal 3*60 + 30, pln.duration
      assert_equal Plan::TIME_DESCRIPTION_AFTERNOON, pln.timeperiod
      assert_equal 14, pln.local_start.hour

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_TODAY, Plan::TIME_DESCRIPTION_LUNCH
      assert_equal Time.utc(2005, 12, 14, 20, 0, 0), pln.start
      assert_equal 60 + 30, pln.duration
      assert_equal Plan::TIME_DESCRIPTION_LUNCH, pln.timeperiod
      assert_equal 12, pln.local_start.hour

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_TODAY, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 14, 17, 0, 0), pln.start
      assert_equal 2*60 + 30, pln.duration
      assert_equal Plan::TIME_DESCRIPTION_MORNING, pln.timeperiod
      assert_equal 9, pln.local_start.hour

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_TODAY, Plan::TIME_DESCRIPTION_BREAKFAST
      assert_equal Time.utc(2005, 12, 14, 15, 0, 0), pln.start
      assert_equal 60 + 30, pln.duration
      assert_equal Plan::TIME_DESCRIPTION_BREAKFAST, pln.timeperiod
      assert_equal 7, pln.local_start.hour

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_TODAY, [13, 5, 2]
      assert_equal Time.utc(2005, 12, 14, 21, 5, 2), pln.start
      assert_equal 13, pln.local_start.hour

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_FUTURE, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2030, 1, 1, 17, 0, 0), pln.start
      assert_equal Time.utc(2030, 1, 1, 17, 0, 0), pln.fuzzy_start
      assert_equal Plan::DATE_DESCRIPTION_FUTURE, pln.dateperiod(tz)
    end

    #MGS- also test a Sunday since this is handled differently for weekends
    Time.set_now_gmt(2005, 12, 11, 12, 0, 0) do
      pln.set_datetime tz, Plan::DATE_DESCRIPTION_THIS_WEEKEND, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 10, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 12, 11, 17, 0, 0), pln.fuzzy_start
      assert_nil pln.local_start
      assert_equal Plan::DATE_DESCRIPTION_THIS_WEEKEND, pln.dateperiod(tz)

      pln.set_datetime tz, Plan::DATE_DESCRIPTION_NEXT_WEEKEND, Plan::TIME_DESCRIPTION_MORNING
      assert_equal Time.utc(2005, 12, 17, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 12, 18, 17, 0, 0), pln.fuzzy_start
      assert_nil pln.local_start
      assert_equal Plan::DATE_DESCRIPTION_NEXT_WEEKEND, pln.dateperiod(tz)
    end
  end
  


  def test_timezone_handling
    pln = Plan.new
    tz = TZInfo::Timezone.get('America/Tijuana')
    #MES- Set "now" to a random date- NOT near a DST border, but this date IS in DST
    Time.set_now_gmt(2005, 10, 13, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_YESTERDAY, Plan::TIME_DESCRIPTION_MORNING)

      #MES- "Yesterday" for the 13th is the 12th, and we want "morning" for PST, which is
      # 8 hours from UTC- 9 + 8 is 17.  But Oct 13 is in DST, so it's one hour less, hence 16.
      assert_equal Time.utc(2005, 10, 12, 16, 0, 0), pln.start
      assert_equal Plan::DATE_DESCRIPTION_YESTERDAY, pln.dateperiod(tz)
    end

    #MES- Same test, but let's do it for a NON DST date
    Time.set_now_gmt(2005, 11, 5, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_YESTERDAY, Plan::TIME_DESCRIPTION_MORNING)

      #MES- "Yesterday" for the 5th is the 4th, and we want "morning" for PST, which is
      # 8 hours from UTC- 9 + 8 is 17.
      assert_equal Time.utc(2005, 11, 4, 17, 0, 0), pln.start
      assert_equal Plan::DATE_DESCRIPTION_YESTERDAY, pln.dateperiod(tz)
    end

    #MES- What if we SPAN a DST border?  Clocks "fall back" one hour on 10/30/2005.
    Time.set_now_gmt(2005, 10, 30, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_YESTERDAY, Plan::TIME_DESCRIPTION_MORNING)

      #MES- "Yesterday" for the 30th is the 29th, and we want "morning" for PST, which is
      # 8 hours from UTC- 9 + 8 is 17.  But the 30th is not DST, and the 29th IS.  We want
      # the time to be DSTish (that is, the right time for the 29th, which is 16, as mentioned
      # above.)
      assert_equal Time.utc(2005, 10, 29, 16, 0, 0), pln.start
      assert_equal Plan::DATE_DESCRIPTION_YESTERDAY, pln.dateperiod(tz)
    end


    #MES- Now run all the same tests, but for "tomorrow"
    #MES- Set "now" to a random date- NOT near a DST border, but this date IS in DST
    Time.set_now_gmt(2005, 10, 13, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_TOMORROW, Plan::TIME_DESCRIPTION_MORNING)

      #MES- "Tomorrow" for the 13th is the 14th, and we want "morning" for PST, which is
      # 8 hours from UTC- 9 + 8 is 17.  But Oct 14 is in DST, so it's one hour less, hence 16.
      assert_equal Time.utc(2005, 10, 14, 16, 0, 0), pln.start
      assert_equal Plan::DATE_DESCRIPTION_TOMORROW, pln.dateperiod(tz)
    end

    #MES- Same test, but let's do it for a NON DST date
    Time.set_now_gmt(2005, 11, 5, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_TOMORROW, Plan::TIME_DESCRIPTION_MORNING)

      #MES- "Tomorrow" for the 5th is the 6th, and we want "morning" for PST, which is
      # 8 hours from UTC- 9 + 8 is 17.
      assert_equal Time.utc(2005, 11, 6, 17, 0, 0), pln.start
      assert_equal Plan::DATE_DESCRIPTION_TOMORROW, pln.dateperiod(tz)
    end

    #MES- What if we SPAN a DST border?  Clocks "fall back" one hour on 10/30/2005.
    Time.set_now_gmt(2005, 10, 29, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_TOMORROW, Plan::TIME_DESCRIPTION_MORNING)

      #MES- "Tomorrow" for the 29th is the 30th, and we want "morning" for PST, which is
      # 8 hours from UTC- 9 + 8 is 17.  But the 30th is not DST, and the 29th IS.  We want
      # the time to NOT be DSTish (that is, the right time for the 30th, which is 17.)
      assert_equal Time.utc(2005, 10, 30, 17, 0, 0), pln.start
      assert_equal Plan::DATE_DESCRIPTION_TOMORROW, pln.dateperiod(tz)
    end


    #MES- Now run all the same tests, but for "this week"
    #MES- Set "now" to a random date- NOT near a DST border, but this date IS in DST
    Time.set_now_gmt(2005, 10, 13, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_THIS_WEEK, Plan::TIME_DESCRIPTION_MORNING)

      #MES- "this week" for the 13th is the 10th to the 16th, and we want "morning" for PST, which is
      # 8 hours from UTC- 9 + 8 is 17.  But Oct 14 is in DST, so it's one hour less, hence 16.
      assert_equal Time.utc(2005, 10, 10, 16, 0, 0), pln.start
      assert_equal Time.utc(2005, 10, 16, 16, 0, 0), pln.fuzzy_start
      assert_equal Plan::DATE_DESCRIPTION_THIS_WEEK, pln.dateperiod(tz)
    end

    #MES- Same test, but let's do it for a NON DST date
    Time.set_now_gmt(2005, 11, 9, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_THIS_WEEK, Plan::TIME_DESCRIPTION_MORNING)

      #MES- "This week" for the 9th is the 7th to the 13th, and we want "morning" for PST, which is
      # 8 hours from UTC- 9 + 8 is 17.
      assert_equal Time.utc(2005, 11, 7, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 11, 13, 17, 0, 0), pln.fuzzy_start
      assert_equal Plan::DATE_DESCRIPTION_THIS_WEEK, pln.dateperiod(tz)
    end

    #MES- THIS_WEEK, LAST_WEEK, and NEXT_WEEK can also cross DST borders, since Skobee
    # considers Monday to be the first day of the week.
    Time.set_now_gmt(2005, 10, 29, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_THIS_WEEK, Plan::TIME_DESCRIPTION_MORNING)

      # "This week" for the 29th is the 24rd to the 30th  But the 30th is across the DST border
      assert_equal Time.utc(2005, 10, 24, 16, 0, 0), pln.start
      assert_equal Time.utc(2005, 10, 30, 17, 0, 0), pln.fuzzy_start
      assert_equal Plan::DATE_DESCRIPTION_THIS_WEEK, pln.dateperiod(tz)
    end

    #MGS- Now run all the same tests, but for "this weekend"
    #MES- Set "now" to a random date- NOT near a DST border, but this date IS in DST
    Time.set_now_gmt(2005, 10, 13, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_THIS_WEEKEND, Plan::TIME_DESCRIPTION_MORNING)

      #MGS- "this weekend" for the 13th is the 15th to the 16th, and we want "morning" for PST, which is
      # 8 hours from UTC- 9 + 8 is 17.  But Oct 14 is in DST, so it's one hour less, hence 16.
      assert_equal Time.utc(2005, 10, 15, 16, 0, 0), pln.start
      assert_equal Time.utc(2005, 10, 16, 16, 0, 0), pln.fuzzy_start
      assert_equal Plan::DATE_DESCRIPTION_THIS_WEEKEND, pln.dateperiod(tz)
    end

    #MGS- Same test, but let's do it for a NON DST date
    Time.set_now_gmt(2005, 11, 9, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_THIS_WEEKEND, Plan::TIME_DESCRIPTION_MORNING)

      #MGS- "this weekend" for the 9th is the 12th to the 13th, and we want "morning" for PST, which is
      # 8 hours from UTC- 9 + 8 is 17.
      assert_equal Time.utc(2005, 11, 12, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 11, 13, 17, 0, 0), pln.fuzzy_start
      assert_equal Plan::DATE_DESCRIPTION_THIS_WEEKEND, pln.dateperiod(tz)
    end

    #MGS- Now run all the same tests, but for "next weekend"
    #MGS- Set "now" to a random date- NOT near a DST border, but this date IS in DST
    Time.set_now_gmt(2005, 10, 13, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_NEXT_WEEKEND, Plan::TIME_DESCRIPTION_MORNING)

      #MGS- "next weekend" for the 13th is the 22nd to the 23rd, and we want "morning" for PST, which is
      # 8 hours from UTC- 9 + 8 is 17.  But Oct 14 is in DST, so it's one hour less, hence 16.
      assert_equal Time.utc(2005, 10, 22, 16, 0, 0), pln.start
      assert_equal Time.utc(2005, 10, 23, 16, 0, 0), pln.fuzzy_start
      assert_equal Plan::DATE_DESCRIPTION_NEXT_WEEKEND, pln.dateperiod(tz)
    end

    #MGS- Same test, but let's do it for a NON DST date
    Time.set_now_gmt(2005, 11, 9, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_NEXT_WEEKEND, Plan::TIME_DESCRIPTION_MORNING)

      #MES- "next weekend" for the 9th is the 19th to the 20th, and we want "morning" for PST, which is
      # 8 hours from UTC- 9 + 8 is 17.
      assert_equal Time.utc(2005, 11, 19, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 11, 20, 17, 0, 0), pln.fuzzy_start
      assert_equal Plan::DATE_DESCRIPTION_NEXT_WEEKEND, pln.dateperiod(tz)
    end

    #MES- Now run all the same tests, but for "this month"
    #MES- Set "now" to a random date- NOT near a DST border, but this date IS in DST
    Time.set_now_gmt(2005, 9, 9, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_THIS_MONTH, Plan::TIME_DESCRIPTION_MORNING)

      assert_equal Time.utc(2005, 9, 1, 16, 0, 0), pln.start
      assert_equal Time.utc(2005, 9, 30, 16, 0, 0), pln.fuzzy_start
      assert_equal Plan::DATE_DESCRIPTION_THIS_MONTH, pln.dateperiod(tz)
    end

    #MES- Same test, but let's do it for a NON DST date
    Time.set_now_gmt(2005, 11, 5, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_THIS_MONTH, Plan::TIME_DESCRIPTION_MORNING)

      assert_equal Time.utc(2005, 11, 1, 17, 0, 0), pln.start
      assert_equal Time.utc(2005, 11, 30, 17, 0, 0), pln.fuzzy_start
      assert_equal Plan::DATE_DESCRIPTION_THIS_MONTH, pln.dateperiod(tz)

      #MES- What if we SPAN a DST border?  Clocks "fall back" one hour on 10/30/2005.
      Time.set_now_gmt(2005, 10, 29, 12, 0, 0)
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_THIS_MONTH, Plan::TIME_DESCRIPTION_MORNING)

      assert_equal Time.utc(2005, 10, 1, 16, 0, 0), pln.start
      assert_equal Time.utc(2005, 10, 31, 17, 0, 0), pln.fuzzy_start
      assert_equal Plan::DATE_DESCRIPTION_THIS_MONTH, pln.dateperiod(tz)

      #MES- We assume that if THIS_MONTH handles timezones correctly, then so do LAST_MONTH and NEXT_MONTH
    end
  end
  
  def test_dateperiod_for_date_timezone
    #MES- See bug 270- dateperiod_for_date should 
    # respect the timezone of the user.
    
    #MES- When "now" in the server timezone is a different
    # day than "now" in the user timezone, it's a tricky case.
    #MES- 7 AM GMT is 11 PM (the previous day) PST.  Two hours later
    # is 1 AM PST- the next day.  7 AM GMT is 11 AM in Dubai.  Two
    # hours later is 1 PM in Dubai- the SAME day!
    Time.set_now_gmt(2005, 11, 5, 7, 0, 0) do    
      start = Time.utc(2005, 11, 5, 9, 0, 0)
      tij = TZInfo::Timezone.get('America/Tijuana')
      assert_equal Plan::DATE_DESCRIPTION_TOMORROW, Plan.dateperiod_for_date(tij, start, start)
      dub = TZInfo::Timezone.get('Asia/Dubai')
      assert_equal Plan::DATE_DESCRIPTION_TODAY, Plan.dateperiod_for_date(dub, start, start)
    end    
  end

  def test_is_expiring
    pln = Plan.new
    tz = TZInfo::Timezone.get('America/Tijuana')
    #MGS- set now to the middle of a week and set the fuzzy date of the plan to be THIS_WEEK
    Time.set_now_gmt(2005, 12, 15, 12, 0, 0) do
      pln.set_datetime(tz, Plan::DATE_DESCRIPTION_THIS_WEEK, Plan::TIME_DESCRIPTION_MORNING)
    end

    #MGS- if we change the time to Friday, this plan shouldnt be expiring
    Time.set_now_gmt(2005, 12, 16, 12, 0, 0) do
      assert !pln.is_expiring?(tz)
    end

    #MGS- if we change the time to Saturday early morning, this plan should be expiring
    Time.set_now_gmt(2005, 12, 17, 10, 0, 0) do
      assert pln.is_expiring?(tz)
    end

    #MGS- if we change the time to Saturday afternoon, this plan should be expiring
    Time.set_now_gmt(2005, 12, 17, 22, 0, 0) do
      assert pln.is_expiring?(tz)
    end

    #MGS- if we change the time to Sunday morning, this plan should be expiring
    Time.set_now_gmt(2005, 12, 18, 13, 0, 0) do
      assert pln.is_expiring?(tz)
    end
  end

  def test_fuzzy
    tz = TZInfo::Timezone.get('America/Tijuana')
    pln = Plan.new
    #MGS- first test the fuzzys
    pln.set_datetime(tz, Plan::DATE_DESCRIPTION_THIS_WEEK, Plan::TIME_DESCRIPTION_MORNING)
    assert pln.fuzzy?(tz)
    pln.set_datetime(tz, Plan::DATE_DESCRIPTION_FUTURE, Plan::TIME_DESCRIPTION_MORNING)
    assert pln.fuzzy?(tz)
    pln.set_datetime(tz, Plan::DATE_DESCRIPTION_NEXT_WEEKEND, Plan::TIME_DESCRIPTION_MORNING)
    assert pln.fuzzy?(tz)
    pln.set_datetime(tz, Plan::DATE_DESCRIPTION_NEXT_MONTH, Plan::TIME_DESCRIPTION_MORNING)
    assert pln.fuzzy?(tz)
    pln.set_datetime(tz, Plan::DATE_DESCRIPTION_LAST_MONTH, Plan::TIME_DESCRIPTION_MORNING)
    assert pln.fuzzy?(tz)

    #MGS- next the solids
    pln.set_datetime(tz, Plan::DATE_DESCRIPTION_TOMORROW, Plan::TIME_DESCRIPTION_MORNING)
    assert !pln.fuzzy?(tz)
    pln.set_datetime(tz, Plan::DATE_DESCRIPTION_TODAY, Plan::TIME_DESCRIPTION_MORNING)
    assert !pln.fuzzy?(tz)
    pln.set_datetime(tz, Plan::DATE_DESCRIPTION_YESTERDAY, Plan::TIME_DESCRIPTION_MORNING)
    assert !pln.fuzzy?(tz)
    pln.set_datetime(tz, [2005, 12, 14], Plan::TIME_DESCRIPTION_MORNING)
    assert !pln.fuzzy?(tz)
    pln.set_datetime(tz, [2007, 1, 1], Plan::TIME_DESCRIPTION_MORNING)
    assert !pln.fuzzy?(tz)
  end
  
  def test_occurs_in_past
    tz = TZInfo::Timezone.get('US/Pacific')
    pln = Plan.new
    pln.set_datetime(tz, Plan::DATE_DESCRIPTION_THIS_WEEK, Plan::TIME_DESCRIPTION_MORNING)
  	
  	assert !pln.occurs_in_past?
  	
  	#MES- If time advances by 8 days, the plan SHOULD be in the past
  	future = Time.now + (8 * 24 * 60 * 60)
    Time.set_now_gmt(future.year, future.month, future.day, future.hour, future.min, future.sec) do
  		assert pln.occurs_in_past?
    end
    
    #MES- Make sure that the transition occurs exactly 6 hours in the future
    exact_time = Time.utc(2006, 11, 12, 14, 20, 0)
    Time.set_now_gmt(exact_time.year, exact_time.month, exact_time.day, exact_time.hour, exact_time.min, exact_time.sec) do
    	tz_exact_time = exact_time - (8 * 60 * 60)
    	tz_five_hrs = tz_exact_time - (5 * 60 * 60 + 59 * 60)
    	pln.set_datetime(tz, [tz_five_hrs.year, tz_five_hrs.month, tz_five_hrs.day], [tz_five_hrs.hour, tz_five_hrs.min, tz_five_hrs.sec])
    	assert !pln.occurs_in_past?
    	tz_six_hrs = tz_exact_time - (6 * 60 * 60 + 60)
    	pln.set_datetime(tz, [tz_six_hrs.year, tz_six_hrs.month, tz_six_hrs.day], [tz_six_hrs.hour, tz_six_hrs.min, tz_six_hrs.sec])
    	assert pln.occurs_in_past?
    end
  end
  
end


#########################################################################################
#MES- Tests that depend on fixtures
#########################################################################################

class PlanTest < Test::Unit::TestCase
  fixtures :plans, :users, :planners, :planners_plans, :places, :emails, :user_atts, :offsets_timezones, :zipcodes
  
  def setup
    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  def test_get_planners
    #MES- Assure that we can get to the planners for a plan
    assert_equal 2, plans(:another_plan).planners.length, 'The "another plan" plan should be associated with two planner'
    assert_equal planners(:existingbob_planner), plans(:another_plan).planners[0], 'The "another plan" plan is associated with wrong planner'

    #MES- Can we add a planner to a plan?
    planners(:first_planner).add_plan(plans(:another_plan))
    pln = Plan.find(plans(:another_plan).id)
    assert_equal 3, pln.planners.length, 'The "another plan" plan should be associated with three planners'
    assert plans(:another_plan).planners.include?(planners(:first_planner)), 'The "another plan" plan does not contain :first_planner'

    #MES- Test the reverse- does the plan appear in the planner?
    cal = planners(:first_planner)
    assert cal.plans.include?(pln), 'The :first_planner planner does not contain the :another_plan plan'

    #MES- If we change the place for a plan, does the cache in the join table get updated?
    pln_with_cache_info = cal.plans.find(pln.id)
    assert_equal places(:first_place).id, pln_with_cache_info.place_id_cache.to_i
    pln.checkpoint_for_revert(users(:existingbob))
    pln.place = places(:another_place)
    pln.save
    cal = planners(:first_planner, :force)
    pln_with_cache_info = cal.plans.find(pln.id)
    assert_equal places(:another_place).id, pln_with_cache_info.place_id_cache.to_i


    #MES- And can we remove them?
    pln.planners.clear
    pln = Plan.find(pln.id)
    assert pln.planners.empty?, 'A plan with no planners should have an empty planner list'

    cal = Planner.find(planners(:first_planner).id)
    assert !cal.plans.include?(pln), 'The :first_planner planner contains the :another_plan plan, but should not'
  end

  def test_ownership
    plan = Plan.find(4)
    assert_equal User.find(7), plan.owner

    plan = Plan.find(5)
    assert_equal User.find(15), plan.owner

    plan = Plan.find(6)
    assert_equal User.find(16), plan.owner

    plan = Plan.find(7)
    assert_equal User.find(13), plan.owner
  end



  def test_find_at_place
    plns = Plan.find_at_place(places(:first_place))
    #MES- There should be 5 plans returned
    assert_equal 5, plns.length, 'Wrong number of plans returned'

    #MES- The order and items returned depend on the current date.
    #  Most of the plans in the fixtures are set to occur at
    #  dates that are relative to the current time.  But one of
    #  the plans (#13, 'plan for place stats') occurs at a specified
    #  date.  Since the results are ordered by time, item 13 may be
    #  towards the beginning of the list, or at the end...
    assert plns.include?(plans(:future_plan_1))
    assert plns.include?(plans(:user_with_friends_plan))
    #MGS- first plan shouldn't be included anymore since it has no name
    assert !plns.include?(plans(:first_plan))
    assert plns.include?(plans(:contact_2_of_user_plan))
    assert plns.include?(plans(:plan_for_place_stats))
    assert plns.include?(plans(:longbob_plan))

    #MES- Try to limit the returns
    plns = Plan.find_at_place(places(:first_place), 2)
    #MES- There should be 2 plans returned
    assert_equal 2, plns.length, 'Wrong number of plans returned'
    #MES- And they should be in a specific order
    assert plns.include?(plans(:future_plan_1))

    #MES- Try passing in an ID
    plns = Plan.find_at_place(places(:first_place))
    #MES- There should be 5 plans returned
    assert_equal 5, plns.length, 'Wrong number of plans returned'
    
    #MES- If one of the plans is marked as private, it should NOT be returned
    pln = plans(:future_plan_1)
    pln.security_level = Plan::SECURITY_LEVEL_PRIVATE
    pln.save!
    plns = Plan.find_at_place(places(:first_place))
    assert !plns.include?(plans(:future_plan_1))
  end

#  def test_local_start
#    #MES- Plans should have a start time in UTC, and a local_start that's
#    # in the timezone of the person who set the time (often the plan owner.)
#
#  end

  def test_revertable_changes
    pln = plans(:first_plan)
    original_start, original_fuzzy_start, original_duration = pln.start, pln.fuzzy_start, pln.duration
    #MES- Set a checkpoint for the plan- what we want to revert to
    pln.checkpoint_for_revert(users(:bob))
    #MES- Change the place
    pln.place = places(:another_place)
    #MES- Change the time
    tz = TZInfo::Timezone.get('America/Tijuana')
    pln.set_datetime(tz, Plan::DATE_DESCRIPTION_THIS_WEEKEND, Plan::TIME_DESCRIPTION_EVENING)
    #MES- Save the object
    pln.save
    assert_equal 4, pln.plan_changes.length
    #MES- Revert to the original state
    # NOTE: Since the first change of each type creates 2 change objects (one to revert to
    # the initial state, and one to revert to the new state) we only want to revert to 
    # the first ones
    chg1 = pln.plan_changes[0]
    chg2 = pln.plan_changes[1]
    pln.revert_from_change(chg1)
    pln.revert_from_change(chg2)
    pln.save
    #MES- Test that the items were, in fact, reverted
    assert_equal places(:first_place), pln.place
    assert_equal original_start, pln.start
    assert_equal original_fuzzy_start, pln.fuzzy_start
    assert_equal original_duration, pln.duration
    
  end
  
  def test_place_revertable_changes
    #MES- Place is a little different from time, since place can be nil
    
    #MES- A plan with no place should be revertable to no place.
    pln = Plan.new
    tz = TZInfo::Timezone.get('America/Tijuana')
    pln.set_datetime(tz, Plan::DEFAULT_DATE, Plan::DEFAULT_TIME)
    pln.save!
    users(:bob).planner.accept_plan(pln, nil, Plan::OWNERSHIP_OWNER)
    pln.checkpoint_for_revert(users(:bob))
    pln.place = places(:another_place)
    pln.save!
    #MES- There will be a change to place, and a change to RSVP- we care about the place one
    assert_equal 2, pln.plan_changes.length
    place_changes = pln.plan_changes.select { |pc| PlanChange::CHANGE_TYPE_PLACE == pc.change_type }
    first_place_chg = place_changes.min { |a, b| a.id <=> b.id }
    assert_equal nil, first_place_chg.initial_place
    assert_equal places(:another_place), first_place_chg.final_place
    
    #MES- Let's change it to another place, for kicks
    pln.checkpoint_for_revert(users(:bob))
    pln.place = places(:place_owned_by_bob)
    pln.save!
    
    pln.checkpoint_for_revert(users(:bob))
    pln.revert_from_change(first_place_chg)
    pln.save!
    assert_equal places(:another_place), pln.place
    
    assert_equal 4, pln.plan_changes.length
    place_changes = pln.plan_changes.select { |pc| PlanChange::CHANGE_TYPE_PLACE == pc.change_type }
    third_place_chg = place_changes.max { |a, b| a.id <=> b.id }
    assert_equal places(:place_owned_by_bob), third_place_chg.initial_place
    assert_equal places(:another_place), third_place_chg.final_place
    
  end
  
  def test_time_revertable_change
    #MES- Time can never be unset for a plan
    pln = Plan.new
    tz = TZInfo::Timezone.get('America/Tijuana')
    pln.set_datetime(tz, Plan::DATE_DESCRIPTION_FUTURE, Plan::TIME_DESCRIPTION_ALL_DAY)
    pln.save!
    users(:bob).planner.accept_plan(pln, nil, Plan::OWNERSHIP_OWNER)
    pln.checkpoint_for_revert(users(:bob))
    pln.set_datetime(tz, Plan::DATE_DESCRIPTION_FUTURE, Plan::TIME_DESCRIPTION_DINNER)
    pln.save!
    #MES- There will be changes to time, and a change to RSVP- we care about the time ones
    time_changes = pln.plan_changes.select { |pc| PlanChange::CHANGE_TYPE_TIME == pc.change_type }
    first_time_chg = time_changes.min { |a, b| a.id <=> b.id }
    assert_equal 0, first_time_chg.initial_time[0].to_i
    assert_equal Plan::TIME_DESCRIPTION_ALL_DAY, first_time_chg.final_time[PlanChange::TIME_CHANGE_TIMEPERIOD_INDEX]
    assert_equal((23*60 + 59), first_time_chg.final_time[PlanChange::TIME_CHANGE_DURATION_INDEX]) #MES- It should be all day- this is the duration for all day
    
    #MES- When the first change is made to a plan, TWO PlanChange objects
    # should be created- one for the ORIGINAL value in the plan, and one
    # for the FINAL value (and there's another change for the RSVP change...)
    assert_equal 3, pln.plan_changes.length
    second_time_chg = time_changes.max { |a, b| a.id <=> b.id }
    assert_equal Plan::TIME_DESCRIPTION_ALL_DAY, second_time_chg.initial_time[PlanChange::TIME_CHANGE_TIMEPERIOD_INDEX]
    assert_equal((23*60 + 59), second_time_chg.initial_time[PlanChange::TIME_CHANGE_DURATION_INDEX])
    assert_equal Plan::TIME_DESCRIPTION_DINNER, second_time_chg.final_time[PlanChange::TIME_CHANGE_TIMEPERIOD_INDEX]
    assert_equal((3*60 + 30), second_time_chg.final_time[PlanChange::TIME_CHANGE_DURATION_INDEX])
    
    pln.checkpoint_for_revert(users(:bob))
    pln.revert_from_change(first_time_chg)
    pln.save!
    assert_equal((23*60 + 59), pln.duration)
  end

  def test_status_change
    #MES- When a plan is altered, the status of users should change
    plan = plans(:another_plan)
    #MES- Before changes, existingbob is invited, longbob is accepted
    exbob = users(:existingbob)
    assert_equal Plan::STATUS_INVITED, plan_status_for_user_helper(exbob, plan)
    lbob = users(:longbob)
    assert_equal Plan::STATUS_ACCEPTED, plan_status_for_user_helper(lbob, plan)

    #MES- FOLLOWING IS DEFUNCT!  We no longer support STATUS_ALTERED, so instead of
    # that, the status should be STATUS_ACCEPTED.
    #MES- If existingbob adds a comment, then longbob's status should change to
    # ALTERED
    plan.checkpoint_for_revert(exbob)
    plan.plan_changes.create(:comment => 'A comment', :owner => exbob)
    plan.save
    exbob = User.find(exbob.id)
    assert_equal Plan::STATUS_INVITED, plan_status_for_user_helper(exbob, plan)
    lbob = User.find(lbob.id)
    assert_equal Plan::STATUS_ACCEPTED, plan_status_for_user_helper(lbob, plan)

    #MES- Now if longbob changes something, he should change to ACCEPTED
    plan.checkpoint_for_revert(lbob)
    plan.plan_changes.create(:comment => 'Another comment', :owner => lbob)
    plan.save
    exbob = User.find(exbob.id)
    assert_equal Plan::STATUS_INVITED, plan_status_for_user_helper(exbob, plan)
    lbob = User.find(lbob.id)
    assert_equal Plan::STATUS_ACCEPTED, plan_status_for_user_helper(lbob, plan)
    
    #MES- A user should be able to change their status...
    exbob.planner.accept_plan(plan, nil, nil, Plan::STATUS_INTERESTED)
    assert_equal Plan::STATUS_INTERESTED, plan_status_for_user_helper(exbob, plan)
    exbob.planner.reject_plan(plan)
    assert_equal Plan::STATUS_REJECTED, plan_status_for_user_helper(exbob, plan)
  end

  def plan_status_for_user_helper(user, plan)
    user.planner.plans.detect { | pln | pln.id == plan.id }.cal_pln_status.to_i
  end

  def test_find_latest_plans
    #MES- If we don't pass in a user object, or the user object isn't geocoded,
    #  then the list of plans isn't constrained by location
    usr = users(:bob)
    usr.lat_max, usr.long_max, usr.lat_min, usr.long_min = nil, nil, nil, nil
    res = Plan.find_latest_plans
    res2 = Plan.find_latest_plans(usr)
    assert_equal res, res2
    
    #MES- The results are ordered by start date, ascending
    assert_equal plans(:first_plan), res[0]
    assert_equal plans(:longbob_plan), res[1]
    assert_equal plans(:contact_1_of_user_plan), res[2]
    assert_equal plans(:plan_for_bob_place), res[3]
    assert_equal plans(:solid_plan_in_expiry_window), res[4]

    #MES- We should be able to limit the number of results
    res = Plan.find_latest_plans(nil, 1)
    assert_equal 1, res.length

    #MES- We should be able to pass in a geocoded user, and results should be
    #  limited to plans that are within the metro of the user.  In the
    #  fixtures, only existingbob is geocoded, so he'll only see his own
    #  stuff.
    res = Plan.find_latest_plans(users(:existingbob))
    assert_equal 4, res.length
    assert_equal plans(:first_plan), res[0]
    
    #MES- If the plan is private, it shouldn't show up in results
    pln = plans(:first_plan)
    pln.security_level = Plan::SECURITY_LEVEL_PRIVATE
    pln.save!
    res = Plan.find_latest_plans
    assert !res.include?(pln)
    res = Plan.find_latest_plans(users(:existingbob))
    assert !res.include?(pln)
  end
  
  def test_add_comment
    #MES- We should be able to make a comment of each type
    pln = plans(:first_plan)
    usr = users(:longbob)
    assert_equal 0, pln.plan_changes.length
    pln.add_comment(usr, 'plain comment')
    pln.add_comment(usr, 'time comment', PlanChange::CHANGE_TYPE_TIME_COMMENT)
    pln.add_comment(usr, 'place comment', PlanChange::CHANGE_TYPE_PLACE_COMMENT)
    
    pln = plans(:first_plan, :force)
    assert_equal 3, pln.plan_changes.length
    plain_cmt = pln.plan_changes.detect {|x| PlanChange::CHANGE_TYPE_COMMENT == x.change_type }
    assert_equal 'plain comment', plain_cmt.comment
    time_cmt = pln.plan_changes.detect {|x| PlanChange::CHANGE_TYPE_TIME_COMMENT == x.change_type }
    assert_equal 'time comment', time_cmt.comment
    place_cmt = pln.plan_changes.detect {|x| PlanChange::CHANGE_TYPE_PLACE_COMMENT == x.change_type }
    assert_equal 'place comment', place_cmt.comment
    
    #MES- No notifications should have happened
    assert_equal 0, @emails.length
    
    #MES- If existingbob has notification turned on, but NOT comment notification, we still shouldn't get 
    # a notification when longbob adds a comment.
    existingbob = users(:existingbob)
    existingbob.set_att(UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION, UserAttribute::PLAN_MODIFIED_ALWAYS)
    existingbob.set_att(UserAttribute::ATT_PLAN_COMMENTED_NOTIFICATION_OPTION, UserAttribute::FALSE_USER_ATT_VALUE)
    pln.add_comment(usr, 'plain comment two')
    assert_equal 0, @emails.length
    
    #MES- Likewise, if existingbob has comment notification, but not notification IN GENERAL, he shouldn't
    # be notified
    existingbob.set_att(UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION, UserAttribute::PLAN_MODIFIED_NEVER)
    existingbob.set_att(UserAttribute::ATT_PLAN_COMMENTED_NOTIFICATION_OPTION, UserAttribute::TRUE_USER_ATT_VALUE)
    pln.add_comment(usr, 'plain comment three')
    assert_equal 0, @emails.length
    
    #MES- If existingbob DOES have notification of comments on, he should get a notification
    existingbob.set_att(UserAttribute::ATT_PLAN_MODIFIED_NOTIFICATION_OPTION, UserAttribute::PLAN_MODIFIED_ALWAYS)
    existingbob.set_att(UserAttribute::ATT_PLAN_COMMENTED_NOTIFICATION_OPTION, UserAttribute::TRUE_USER_ATT_VALUE)
    pln.add_comment(usr, 'plain comment four')
    assert_equal 1, @emails.length
    @emails.clear
    pln.add_comment(usr, 'time comment two', PlanChange::CHANGE_TYPE_TIME_COMMENT)
    assert_equal 1, @emails.length
    @emails.clear
    pln.add_comment(usr, 'place comment two', PlanChange::CHANGE_TYPE_PLACE_COMMENT)
    assert_equal 1, @emails.length    
  end
  
  def test_security_level
    #MES- A new plan should have a security level of public
    pln = Plan.new
    assert_equal Plan::SECURITY_LEVEL_PUBLIC, pln.security_level
    pln.save
    pln = Plan.find(pln.id)
    assert_equal Plan::SECURITY_LEVEL_PUBLIC, pln.security_level
    
    #MES- If a planner accepts the plan, the security level should go into the planners_plans info
    plnr = planners(:first_planner)
    plnr.accept_plan(pln)
    pln = plnr.plans.detect{ |p| p.id == pln.id }
    assert_equal Plan::SECURITY_LEVEL_PUBLIC, pln.plan_security_cache.to_i
    
    #MES- If we change the security level, it should... change!
    pln = Plan.find(pln.id)    
    pln.security_level = Plan::SECURITY_LEVEL_PRIVATE
    pln.save
    pln = Plan.find(pln.id)
    assert_equal Plan::SECURITY_LEVEL_PRIVATE, pln.security_level
    
    #MES- And it should change in the cache
    pln = plnr.plans(true).detect{ |p| p.id == pln.id }
    assert_equal Plan::SECURITY_LEVEL_PRIVATE, pln.plan_security_cache.to_i
    
  end
  
  def test_cancel_uncancel
    #MES- Cancelling a plan should set all attendees to cancelled
    pln = plans(:first_plan)
    pln.cancel
    pln = plans(:first_plan, true)
    pln.planners.each do | plnr |
      assert_equal Plan::STATUS_CANCELLED, plnr.cal_pln_status.to_i
    end
    assert pln.cancelled?
    
    #MES- Uncancelling it should set the user that uncancelled it
    #  to accepted, and everyone else to invited
    usr = users(:longbob)
    pln.uncancel(usr)
    pln = plans(:first_plan, true)
    pln.planners.each do | plnr |
      if plnr.id == usr.planner.id
        assert_equal Plan::STATUS_ACCEPTED, plnr.cal_pln_status.to_i
      else
        assert_equal Plan::STATUS_INVITED, plnr.cal_pln_status.to_i
      end
    end
    assert !pln.cancelled?
    
    
  end
  
  def test_flickr_ids
    #MES- flickr_ids should return an array of the flickr IDs associated with users for a plan
    pln = plans(:first_plan)
    assert pln.flickr_ids.empty?
    
    #MES- If we set the flickr id for one of the attendees, we should get it back
    usr = users(:longbob)
    usr.set_att(UserAttribute::ATT_FLICKR_ID, 'longbob_id')
    usr.save!
    
    pln = plans(:first_plan, true)
    f_ids = pln.flickr_ids
    assert_equal 1, f_ids.length
    assert f_ids.member?('longbob_id')
    
    #MES- Adding another should result in two...
    usr = users(:existingbob)
    usr.set_att(UserAttribute::ATT_FLICKR_ID, 'existingbob_id')
    usr.save!
    
    pln = plans(:first_plan, true)
    f_ids = pln.flickr_ids
    assert_equal 2, f_ids.length
    assert f_ids.member?('longbob_id')
    assert f_ids.member?('existingbob_id')
  end
  
  def test_could_have_photos
    #MES- If nobody on the plan has a Flickr ID, then there can't be photos
    pln = plans(:first_plan)
    assert !pln.could_have_photos?
    
    #MES- If someone on the plan has a flickr ID, there can be photos IFF the plan
    #  occurs in the past
    usr = users(:longbob)
    usr.set_att(UserAttribute::ATT_FLICKR_ID, 'longbob_id')
    usr.save!
    
    pln = plans(:first_plan, true)
    assert !pln.could_have_photos?
    
    past_time = Time.now - (24 * 60 * 60)
    pln.start, pln.fuzzy_start = past_time, past_time
    
    assert pln.could_have_photos?
    #MES- NOTE: Not saving the changes here.

    #MES- The plan can also have photos if the flickr_tags are not blank
    pln = plans(:first_plan, true)
    assert !pln.could_have_photos?
    pln.flickr_tags = ''
    assert !pln.could_have_photos?
    pln.flickr_tags = 'test'
    assert pln.could_have_photos?
    
    #MES- BUT, if no users have flickr IDs, then the tags are not sufficient
    usr = users(:longbob)
    usr.delete_att(UserAttribute::ATT_FLICKR_ID)
    usr.save!
    pln = plans(:first_plan, true)
    assert !pln.could_have_photos?
    pln.flickr_tags = 'test'
    assert !pln.could_have_photos?
    
    
  end
  
  def test_flickr_photos_info
    #MES- If nobody on the plan has a Flickr ID, then there can't be photos
    pln = plans(:first_plan)
    assert pln.flickr_photos_info(nil).empty?
    
    #MES- If someone on the plan has a flickr ID, there can be photos IF the plan
    #  occurs in the past
    usr = users(:longbob)
    usr.set_att(UserAttribute::ATT_FLICKR_ID, 'longbob_id')
    usr.save!
    
    pln = plans(:first_plan, true)
    past_time = Time.now - (24 * 60 * 60)
    pln.start, pln.fuzzy_start = past_time, past_time
    #MES- If we call flickr_photos_info with no max length, it should default to 10
    photo_info = pln.flickr_photos_info(nil)
    assert !photo_info.empty?
    assert_equal 10, photo_info.length
    
    #MES- If we constraint to a certian number of photos, we should get only that number back
    photo_info = pln.flickr_photos_info(nil, 5)
    assert !photo_info.empty?
    assert_equal 5, photo_info.length
    
    #MES- If there are two users with flickr IDs, we should be able to get
    #  photos from both of them
    usr = users(:existingbob)
    usr.set_att(UserAttribute::ATT_FLICKR_ID, 'existingbob_id')
    usr.save!
    
    #MES- Our mock returns 20 photos per user
    pln = plans(:first_plan, true)
    pln.start, pln.fuzzy_start = past_time, past_time
    photo_info = pln.flickr_photos_info(nil, 500)
    assert !photo_info.empty?
    assert_equal 40, photo_info.length
    
    #MES- The first 20 should be from existing bob, and the second 20 should be
    #  from longbob
    0.upto(19) do |idx|
      assert_equal 'dummy_source_existingbob_id', photo_info[idx][0]
      assert_equal 'dummy_url_existingbob_id', photo_info[idx][1]
    end
    20.upto(39) do |idx|
      assert_equal 'dummy_source_longbob_id', photo_info[idx][0]
      assert_equal 'dummy_url_longbob_id', photo_info[idx][1]
    end
    
    #MES- We should NOT get any photos if the plan occurs in the future, since
    #  no photos could have been taken at the event
    pln = plans(:first_plan, true)
    photo_info = pln.flickr_photos_info(nil)
    assert photo_info.empty?
    
    #MES- But if we associated photo tags with the plan, then we CAN find
    #  photos before it occurs
    pln.flickr_tags = 'test, test2'
    photo_info = pln.flickr_photos_info(nil)
    assert_equal 10, photo_info.length
    
  end
  
  def test_can_edit
    #MES- For normal plans, only those who have accepted OR are the owner can edit them
    
    #MES- Existingbob has not accepted another_plan, but he's the owner
    pln = plans(:another_plan)
    ebob_plnr = planners(:existingbob_planner)
    assert pln.can_edit?(ebob_plnr)
    
    #MES- Longbob HAS accepted another_plan
    lbob_plnr = planners(:planner_for_longbob)
    assert pln.can_edit?(lbob_plnr)
    
    #MES- Bob isn't on the plan at all
    bob_plnr = planners(:first_planner)
    assert !pln.can_edit?(bob_plnr)
    
    #MES- Put user_with_friends on the plan, NOT accepted- should not be able to edit
    uwf_plnr = planners(:user_with_friends_planner)
    uwf_plnr.add_plan(pln)
    assert !pln.can_edit?(uwf_plnr)
    
    #MES- For locked plans, only the owner(s) can edit them
    pln.lock_status = Plan::LOCK_STATUS_OWNERS_ONLY
    pln.save!
    
    #MES- Existingbob is an owner, but hasn't accepted the plan
    assert pln.can_edit?(ebob_plnr)
    
    #MES- Longbob is not an owner
    assert !pln.can_edit?(lbob_plnr)
    
    #MES- Bob isn't on the plan at all
    assert !pln.can_edit?(bob_plnr)
    
    #MES- user_with_friends hasn't accepted the plan, and is not an owner
    assert !pln.can_edit?(uwf_plnr)
    
    #MES- A nil planner should NOT be able to edit a plan
    assert !pln.can_edit?(nil)
  end

  #MES- TODO: We SHOULD test english_for_datetime here, but the output of
  #  that function is in flux, so I don't want to spend a lot of time on
  #  writing tests.
end
