#MES- This tiny program is used to generate flatfiles to be loaded into the DB.
# This is a (relatively) quick and easy way to generate a large database for scale
# testing.
#
# You can control the size of the resultant database by tweaking the constants below.
# Of particular interest are NUM_USERS, NUM_PLANS_PER_USER, and NUM_PLACES.
#
# Running this Ruby program will generate various DAT files in the current directory.
# Additionally, it will generate a file called load.sql which can be used to load
# all of the DAT files into the database (as well as truncating tables, etc.)


require 'date'
NUM_USERS = 100000
CONTACTS_PER_USER = 2

NUM_PLANS_PER_USER = 10

NUM_PLACES = 20000

FIRST_PLACE_STAT_HOUR = 19
NUM_PLACE_STAT_HOURS = 3

TRUNCATE_STATEMENT = "truncate table %s;"
LOAD_STATEMENT = "load data infile '%s' replace into table %s;"

FILE_PATH = File.dirname(File.expand_path(__FILE__))

def table_helper(load_file, table_name)
  data_file = File.join(FILE_PATH, "#{table_name}.dat")
  load_file.puts format(TRUNCATE_STATEMENT, table_name)
  load_file.puts format(LOAD_STATEMENT, data_file, table_name)
  load_file.puts ''
  open(data_file, "wb") do | f |
    yield f
  end
end


open(File.join(FILE_PATH, 'load.sql'), "w") do | load_file |

  load_file.puts 'DROP TABLE users_fulltext;'
  load_file.puts 'DROP TRIGGER users_ft_ins_tr;'
  load_file.puts 'DROP TRIGGER users_ft_upd_tr;'
  load_file.puts 'DROP TRIGGER users_ft_del_tr;'


  time_str = (Time.now-(45)).fmt_for_mysql

  #MES- User table looks like this:
  #CREATE TABLE `users` (
  #  `id` <%= @pk %>,
  #  `login` varchar(80) NOT NULL default '',
  #  `salted_password` varchar(40) NOT NULL default '',
  #  `real_name` varchar(160) default NULL,
  #  `description` text default NULL,
  #  `salt` varchar(40) NOT NULL default '',
  #  `security_token` varchar(40) default NULL,
  #  `token_expiry` <%= @datetime %> default NULL,
  #  `deleted` int(11) default '0',
  #  `delete_after` <%= @datetime %> default NULL,
  #  `image_id` int(11),
  #  `thumbnail_id` int(11),
  #  `time_zone` varchar(40) default NULL,
  #  `user_type` int(11) default '0',
  #  `lat` float default NULL,
  #  `long` float default NULL,
  #  `lat_max` float default NULL,
  #  `lat_min` float default NULL,
  #  `long_max` float default NULL,
  #  `long_min` float default NULL,
  #  `generation_num` int(11) default 0,
  #  `invited_by` int(11) default 0,
  #  `created_at` <%= @datetime %>,
  #  `updated_at` <%= @datetime %>
  #) <%= @options %>;
  table_helper(load_file, 'users') do | f |
    1.upto(NUM_USERS) do | id |
      row = [id.to_s]
      row << "user_#{id}"
      row << '00dd8faacfdb49664185d24c3f5db9d7b762e49f'
      row << "real_name_#{id}"
      row << ''
      row << '18cf01c1d67b944c92aff1c8a67f4c4bbd82764d'
      row << ''
      row << '\N'
      row << '0'
      row << '\N'
      row << "#{id}"
      row << "#{id + NUM_USERS + 1}"
      row << "US/Pacific"
      row << '0'
      row << 37.5
      row << -122.5
      row << 38.0
      row << 37.0
      row << -122.0
      row << -123.0
      row << 0
      row << 0
      row << '\N'
      row << '\N'

      f.write row.join("\t")
      f.write "\n"
    end
  end
  
  
  #MES- emails looks like this:
  #CREATE TABLE `emails` (
  #  `id` <%= @pk %>,
  #  `user_id` int(11) NOT NULL,
  #  `address` varchar(60) NOT NULL default '',
  #  `confirmed` tinyint default 0,
  #  `primary` tinyint default 0
  #) <%= @options %>;
  table_helper(load_file, 'emails') do | f |
    1.upto(NUM_USERS) do | id |
      row = [id.to_s]
      row << id.to_s
      row << "user_#{id}@skobee.com"
      row << '1'
      row << '1'

      f.write row.join("\t")
      f.write "\n"
    end
  end


  #MES- User_contacts looks like this:
  #CREATE TABLE `user_contacts` (
  #  `user_id` int(11) NOT NULL default '0',
  #  `contact_id` int(11) NOT NULL default '0',
  #  `connections` int(11) default 0,
  #  `friend_status` int(11) default 0,
  #  `clipboard_status` int(11) default 0,
  #  `style` varchar(255) default NULL,
  #  `contact_created_at` <%= @datetime %> default NULL,
  #  PRIMARY KEY  (`user_id`,`contact_id`)
  #) <%= @options %>;
  table_helper(load_file, 'user_contacts') do | f |
    CONTACTS_PER_USER.upto(NUM_USERS) do | id |
      CONTACTS_PER_USER.downto(1) do | delta |
        row = [id.to_s]
        row << "#{id - delta}"
        row << '1'
        row << '1'
        row << '0'
        row << '\N'
        row << time_str
        f.write row.join("\t")
        f.write "\n"
      end
    end
  end


  #MES- Plans looks like this:
  #CREATE TABLE `plans` (
  #  `id` <%= @pk %>,
  #  `name` varchar(255) default NULL,
  #  `place_id` int(11) default NULL,
  #  `start` <%= @datetime %> default NULL,
  #  `timeperiod` int(11) default 0,	/* MES- A constant from Plan::TIME_DESCRIPTION_* */
  #  `duration` int(11) default NULL,         /* MES- The duration is recorded in minutes */
  #  `fuzzy_start` <%= @datetime %> default NULL,   /* MES- Fuzzy start is the last possible time that the plan could start (expected to be equal to or later than 'start' */
  #  `local_start` <%= @datetime %> default NULL,   /* MES- This is the start time of plan, in the timezone of the user that set the start time */
  #  `created_at` <%= @datetime %>,
  #  `updated_at` <%= @datetime %>
  #) <%= @options %>;
  dt_tomorrow = Date.today + 1
  tm_tomorrow_dinner_start_local = Time.local(dt_tomorrow.year, dt_tomorrow.mon, dt_tomorrow.day, 18, 0, 0)
  str_evt_start_local = tm_tomorrow_dinner_start_local.fmt_for_mysql
  tm_tomorrow_dinner_start = tm_tomorrow_dinner_start_local.getutc
  str_evt_start = tm_tomorrow_dinner_start.fmt_for_mysql

  table_helper(load_file, 'plans') do | f |
    plan_id = 1
    1.upto(NUM_USERS) do | user_id |
      1.upto(NUM_PLANS_PER_USER) do | plan_num |
        place_id = (plan_id % NUM_PLACES) + 1
        row = ["#{plan_id}"]
        row << "plan #{plan_id}"
        row << "#{place_id}"
        row << "#{str_evt_start}"
        row << "#{Plan::TIME_DESCRIPTION_DINNER}"
        row << "#{3*60 + 30}"
        row << "#{str_evt_start}"
        row << "#{str_evt_start_local}"
        row << '\N'
        row << '\N'
        
        f.write row.join("\t")
        f.write "\n"
        plan_id += 1
      end
    end
  end


  #MES- Planners looks like this:
  #CREATE TABLE `planners` (
  #  `id` <%= @pk %>,
  #  `name` varchar(255) default NULL,
  #  `user_id` int(11) default NULL,
  #  `visibility_type` int(11) default NULL,
  #  `created_at` <%= @datetime %>,
  #  `updated_at` <%= @datetime %>
  #) <%= @options %>;
  table_helper(load_file, 'planners') do | f |
    1.upto(NUM_USERS) do | id |
      row = ["#{id}"]
      row << "default"
      row << "#{id}"
      row << "0"
      row << '\N'
      row << '\N'
      f.write row.join("\t")
      f.write "\n"
    end
  end


  #MES- Planners_plans looks like this:
  #CREATE TABLE `planners_plans` (
  #  `planner_id` int(11) NOT NULL default '0',
  #  `plan_id` int(11) NOT NULL default '0',
  #  `cal_pln_status` int(11) default NULL,
  #  `ownership` int(11) default '0',
  #  `reminder_state` int(11) default NULL,
  #  `planner_visibility_cache` int(11) default NULL,
  #  `plan_security_cache` int(11) default NULL,
  #  `place_id_cache` int(11) default NULL,
  #  `user_id_cache` int(11) default NULL,
  #  PRIMARY KEY  (`planner_id`,`plan_id`)
  #) <%= @options %>;
  table_helper(load_file, 'planners_plans') do | f |
    plan_id = 1
    1.upto(NUM_USERS) do | user_id |
      1.upto(NUM_PLANS_PER_USER) do | plan_num |
        place_id = (plan_id % NUM_PLACES) + 1

        row = ["#{user_id}"]
        row << "#{plan_id}"
        row << "2"
        row << "1"
        row << '\N'
        row << '0'
        row << '0'
        row << ((plan_id % NUM_PLACES) + 1).to_s
        row << user_id.to_s
        f.write row.join("\t")
        f.write "\n"
        plan_id += 1
      end
    end
  end
  
  #MES- Plans_changes looks like this:
  #CREATE TABLE `plan_changes` (
  #  `id` <%= @pk %>,
  #  `plan_id` int(11) NOT NULL default '0',
  #  `change_type` int(11) NOT NULL default '0',
  #  `owner_id` int(11) default NULL,
  #  `initial_value` varchar(512) default NULL,
  #  `final_value` varchar(512) default NULL,
  #  `comment` varchar(4096) default NULL,
  #  `created_at` <%= @datetime %>,
  #  `updated_at` <%= @datetime %>
  #) <%= @options %>;
  table_helper(load_file, 'plan_changes') do | f |
    plan_id = 1
    1.upto(NUM_USERS) do | user_id |
      1.upto(NUM_PLANS_PER_USER) do | plan_num |
        place_id = (plan_id % NUM_PLACES) + 1

        row = [plan_id.to_s]
        row << plan_id.to_s
        row << "0"
        row << user_id.to_s
        row << '\N'
        row << '\N'
        row << 'Generic comment'
        row << '\N'
        row << '\N'
        f.write row.join("\t")
        f.write "\n"
        plan_id += 1
      end
    end
  end


  #MES- Places looks like this:
  #CREATE TABLE `places` (
  #  `id` <%= @pk %>,
  #  `name` varchar(255) default NULL,
  #  `user_id` int(11) default NULL,
  #  `public` tinyint default 0,
  #  `public_status` tinyint default 0,
  #  `location` varchar(512) default NULL,
  #  `address` varchar(512) default NULL,
  #  `city` varchar(512) default NULL,
  #  `state` varchar(512) default NULL,
  #  `zip` varchar(10) default NULL,
  #  `lat` float default NULL,
  #  `long` float default NULL,
  #  `geocoded` int default 0,
  #  `url` varchar(512) default NULL,
  #  `click_url` varchar(512) default NULL,
  #  `yahoo_url` varchar(512) default NULL,
  #  `yahoo_click_url` varchar(512) default NULL,
  #  `phone` varchar(30) default NULL,
  #  `normalized_name` varchar(255) default NULL,
  #  `meta_info` varchar(255) default NULL,
  #  `created_at` <%= @datetime %>,
  #  `updated_at` <%= @datetime %>,
  #  `average_rating` int default NULL,
  #  `total_ratings` int default 0,
  #  `total_reviews` int default 0,
  #  `last_review_date` datetime default NULL,
  #  <%= @fulltext %>(normalized_name)
  #) <%= @ftindex_options %>;


  table_helper(load_file, 'places') do | f |
    1.upto(NUM_PLACES) do | id |
      row = ["#{id}"]
      row << "place #{id}"
      row << '\N'
      row << '0'
      row << '0'
      row << "#{id} Polk St., San Francisco, CA"
      row << "#{id} Polk St."
      row << 'San Francisco'
      row << 'CA'
      row << '94117'
      row << "37.791840"
      row << "-122.421069"
      row << "1"
      row << "http://www.yelp.com/biz/7qSq-m4LRu3PAfroD-LKJg"
      row << "http://www.click-url.tv"
      row << "http://www.yahoo-url.tv"
      row << "http://www.yahoo-click-url.tv"
      row << "4154742280"
      row << "place #{id}"
      row << '\N'
      row << '\N'
      row << '\N'
      row << '\N'
      row << '0'
      row << '0'
      row << '\N'
      
      f.write row.join("\t")
      f.write "\n"
    end
  end


  #MES- Place usage stats looks like this:
  #CREATE TABLE `place_usage_stats` (
  #  `place_id` int(11) NOT NULL,
  #  `day` int(11) NOT NULL,
  #  `hour` int(11) NOT NULL,
  #  `num_plans` int(11) NOT NULL default 0,      /* MES- The number of plans that occurred at this place on the indicated day, in the indicated hour */
  #  `num_user_plans` int(11) NOT NULL default 0,   /* MES- The number of users that attended plans at this place on the indicatedd, in the indicated hour */
  #  PRIMARY KEY  (`place_id`,`day`,`hour`)
  #) <%= @options %>;
  table_helper(load_file, 'place_usage_stats') do | f |
    1.upto(NUM_PLACES) do | id |
      0.upto(6) do | day |
        FIRST_PLACE_STAT_HOUR.upto(FIRST_PLACE_STAT_HOUR + NUM_PLACE_STAT_HOURS - 1) do | hour |
          row = ["#{id}"]
          row << "#{day}"
          row << "#{hour}"
          row << "#{5 - ((id + day + hour) % 5)}"
          row << "#{(id + day + hour) % 10}"
          f.write row.join("\t")
          f.write "\n"
        end
      end
    end
  end


  #MES- Pictures looks like this:
  #CREATE TABLE `pictures` (
  #  `id` <%= @pk %>,
  #  `name` varchar(255) default NULL,
  #  `extension` varchar(255) default NULL,
  #  `content_type` varchar(255) default NULL,
  #  `data` text,
  #  `created_at` <%= @datetime %>,
  #  `updated_at` <%= @datetime %>
  #) <%= @options %>;
  table_helper(load_file, 'pictures') do | f |
    1.upto(NUM_USERS) do | id |
      #MES- Two images.  One for the main image, one for the thumbnail
  #MES- TODO: How will we handle the binary data?
      row = ["#{id}"]
      row << "pict_#{id}.jpg"
      row << ".jpg"
      row << "image/jpeg"
      row << '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsL\nDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/\n2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIy\nMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAAyADIDASIAAhEBAxEB/8QA\nGwAAAgMBAQEAAAAAAAAAAAAAAAYDBAUHAQL/xAAwEAACAQMDAgUCBAcAAAAA\nAAABAgMABBEFEiExQQYTFFFhInEVIzLRM0JSgaGiwf/EABkBAAIDAQAAAAAA\nAAAAAAAAAAIEAAEDBf/EAB8RAAICAwACAwAAAAAAAAAAAAABAhESITEDEwQy\nUf/aAAwDAQACEQMRAD8AZbXXbO3GHc5HBCDdTHpuradeYWKUlu/B/wC0l22o\npo8clvFaGWWIZdVA98da07a4ubq2WWWNoHZS2MYKfBqkP02OskUCJv3ZWlrU\nbu7cslhaLKf6mbCiq9vfahc6LPI0iLsbauVyTgfvWdH6i6sVhSXZKVIZu4f3\n+1FdlU0jD1yLVo4jJdpCQeqxnPH70mafpc6tqMsYGyNtxXvj4p1m0/VFkjiu\nLjzyzHfxgY7Y9qrW1qLFNbkILfk9T74NRdMpxTuxU8yQjr/rRUxZQSMNxRWo\nnjE7HBp9vLcmcggkdsc1NdW4kgdYwcdSSRUemOssIJPYEVrvs9Ky8AMCtLrh\n1tXYuWB36bconQio9JhW43qDhkPTpV6zT0TyR+VvQrjIqtbl7WaWQxlWPb4+\naherPb60aNGKgZA5pI1S4EdreKCN0rIpHx3p9urhpLdmxkdMiuX61kam4PPF\nHDbF/O6WigDwOKK+RjFFMYnOzZ0Xwbqy6hpMLAgsBtYdwe9NdzvSJWiAZgP5\njxXHfBV5Jbu0sAJAAMkY7/IrpkWswTwqyycHquaRTtHXarROsuon9PkRj3Ck\n1TltbmabzLm5eVRy3YD+1akQW+iCqQq98nrUF1GVZLGGVS8nGB2XvRW6CyVE\nczPJaRwLEyRSHmXHAFKHinwy8DettZDIhGHRuo+R8V01Ynitlhl2so61k6jb\nZhbaMgjp8VLa2jF4y+xxzy5hx5X+RRTFLo0Rmc4I+o9qKnskaer4/wCGP4N4\nwR12itzVPy7/AOj6cjnHFFFBDhc+jJo7N+GA7jn71c0Q7tYlLckbeT9qKK1f\nAHwapP0Gs+4/ht9qKKhmjAZF3t9I6+1FFFCMn//Z\n'
      row << '\N'
      row << '\N'
      
      f.write row.join("\t")
      f.write "\n"


      row = ["#{id + NUM_USERS + 1}"]
      row << "pict_#{id + NUM_USERS + 1}.jpg"
      row << ".jpg"
      row << "image/jpeg"
      row << '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsL\nDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/\n2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIy\nMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAAyADIDASIAAhEBAxEB/8QA\nGwAAAgMBAQEAAAAAAAAAAAAAAAYDBAUHAQL/xAAwEAACAQMDAgUCBAcAAAAA\nAAABAgMABBEFEiExQQYTFFFhInEVIzLRM0JSgaGiwf/EABkBAAIDAQAAAAAA\nAAAAAAAAAAIEAAEDBf/EAB8RAAICAwACAwAAAAAAAAAAAAABAhESITEDEwQy\nUf/aAAwDAQACEQMRAD8AZbXXbO3GHc5HBCDdTHpuradeYWKUlu/B/wC0l22o\npo8clvFaGWWIZdVA98da07a4ubq2WWWNoHZS2MYKfBqkP02OskUCJv3ZWlrU\nbu7cslhaLKf6mbCiq9vfahc6LPI0iLsbauVyTgfvWdH6i6sVhSXZKVIZu4f3\n+1FdlU0jD1yLVo4jJdpCQeqxnPH70mafpc6tqMsYGyNtxXvj4p1m0/VFkjiu\nLjzyzHfxgY7Y9qrW1qLFNbkILfk9T74NRdMpxTuxU8yQjr/rRUxZQSMNxRWo\nnjE7HBp9vLcmcggkdsc1NdW4kgdYwcdSSRUemOssIJPYEVrvs9Ky8AMCtLrh\n1tXYuWB36bconQio9JhW43qDhkPTpV6zT0TyR+VvQrjIqtbl7WaWQxlWPb4+\naherPb60aNGKgZA5pI1S4EdreKCN0rIpHx3p9urhpLdmxkdMiuX61kam4PPF\nHDbF/O6WigDwOKK+RjFFMYnOzZ0Xwbqy6hpMLAgsBtYdwe9NdzvSJWiAZgP5\njxXHfBV5Jbu0sAJAAMkY7/IrpkWswTwqyycHquaRTtHXarROsuon9PkRj3Ck\n1TltbmabzLm5eVRy3YD+1akQW+iCqQq98nrUF1GVZLGGVS8nGB2XvRW6CyVE\nczPJaRwLEyRSHmXHAFKHinwy8DettZDIhGHRuo+R8V01Ynitlhl2so61k6jb\nZhbaMgjp8VLa2jF4y+xxzy5hx5X+RRTFLo0Rmc4I+o9qKnskaer4/wCGP4N4\nwR12itzVPy7/AOj6cjnHFFFBDhc+jJo7N+GA7jn71c0Q7tYlLckbeT9qKK1f\nAHwapP0Gs+4/ht9qKKhmjAZF3t9I6+1FFFCMn//Z\n'
      row << '\N'
      row << '\N'
      
      f.write row.join("\t")
      f.write "\n"
    end
  end



  #MES- Geocode cache entries looks like this:
  #CREATE TABLE `geocode_cache_entries` (
  #  `id` <%= @pk %>,
  #  `location` varchar(512) default NULL,
  #  `normalized_location` varchar(512) NULL,
  #  `address` varchar(512) default NULL,
  #  `city` varchar(512) default NULL,
  #  `state` varchar(512) default NULL,
  #  `zip` varchar(10) default NULL,
  #  `lat` float default NULL,
  #  `long` float default NULL,
  #  `created_at` <%= @datetime %>,
  #  `updated_at` <%= @datetime %>
  #) <%= @options %>;
  #CREATE INDEX `location_string_index` ON `geocode_cache_entries` (location(100));
  table_helper(load_file, 'geocode_cache_entries') do | f |
    1.upto(NUM_PLACES) do | id |
      row = ["#{id}"]
      row << "#{id} Polk St., San Francisco, CA"
      row << "#{id} Polk Street, San Francisco, CA, 94117"
      row << "#{id} Polk Street"
      row << "San Francisco"
      row << "CA"
      row << "94117"
      row << "37.791840"
      row << "-122.421069"
      row << '\N'
      row << '\N'
      f.write row.join("\t")
      f.write "\n"
    end
  end


  #MES- Comments looks like this:
  #CREATE TABLE `comments` (
  #  `id` <%= @pk %>,
  #  `owner_id` int(11) default NULL,
  #  `body` varchar(512) default NULL,
  #  `created_at` <%= @datetime %>,
  #  `updated_at` <%= @datetime %>
  #) <%= @options %>;
  table_helper(load_file, 'comments') do | f |
    1.upto(NUM_PLACES) do | id |
      row = ["#{id}"]
      row << "#{(id % NUM_USERS) + 1}"
      row << "Generic body for a comment"
      row << time_str
      row << time_str
      f.write row.join("\t")
      f.write "\n"
    end
  end


  #MES- Comments places looks like this:
  #CREATE TABLE `comments_places` (
  #  `comment_id` int(11) NOT NULL default '0',
  #  `place_id` int(11) NOT NULL default '0',
  #  PRIMARY KEY  (`comment_id`,`place_id`)
  #) <%= @options %>;
  table_helper(load_file, 'comments_places') do | f |
    1.upto(NUM_PLACES) do | id |
      row = ["#{id}"]
      row << "#{id}"
      f.write row.join("\t")
      f.write "\n"
    end
  end

  #MES- Truncate the tables we're not loading
  load_file.puts format(TRUNCATE_STATEMENT, 'user_atts')
  load_file.puts format(TRUNCATE_STATEMENT, 'sessions')
  load_file.puts format(TRUNCATE_STATEMENT, 'feedbacks')
  load_file.puts format(TRUNCATE_STATEMENT, 'plan_changes')
  
  
  load_file.puts 'CREATE TABLE `users_fulltext` (`user_id` int(11) default NULL, `searchable` varchar(250) default NULL) ENGINE=MYISAM DEFAULT CHARSET=utf8;'
  load_file.puts "INSERT INTO users_fulltext (user_id, searchable) SELECT id, CONCAT(login, ' ', IFNULL(real_name, '')) FROM users;"
  load_file.puts 'CREATE FULLTEXT INDEX users_ft_searchable_idx ON users_fulltext(searchable);'
  load_file.puts "CREATE TRIGGER users_ft_ins_tr AFTER INSERT ON users FOR EACH ROW INSERT INTO users_fulltext SET user_id = NEW.id, searchable = CONCAT(NEW.login, ' ', IFNULL(NEW.real_name, ''));"
  load_file.puts "CREATE TRIGGER users_ft_upd_tr AFTER UPDATE ON users FOR EACH ROW UPDATE users_fulltext SET searchable = CONCAT(NEW.login, ' ', IFNULL(NEW.real_name, '')) WHERE user_id = NEW.id;"
  load_file.puts 'CREATE TRIGGER users_ft_del_tr AFTER DELETE ON users FOR EACH ROW DELETE FROM users_fulltext WHERE user_id = OLD.id;'

end

