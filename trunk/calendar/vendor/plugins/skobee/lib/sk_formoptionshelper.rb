#MES- From C:\ruby\lib\ruby\gems\1.8\gems\actionpack-1.12.1\lib\action_view\helpers\form_options_helper.rb
module ActionView
  module Helpers
    module FormOptionsHelper

      AVAILABLE_ZONES = [
        ['-12:00 International Date Line West', 'Pacific/Kwajalein'], #MES- Pacific/Kwajalein is GMT -12 with no DST, so I think it's what we want
        ['-11:00 Midway Island, Samoa', 'Pacific/Midway'],
        ['-10:00 Adak', 'America/Adak'],
        ['-10:00 Hawaii', 'US/Hawaii'],
        ['-10:00 Tahiti', 'Pacific/Tahiti'],
        ['-09:00 Alaska', 'US/Alaska'],
        ['-08:00 Pacific Time (US & Canada); Tijuana', 'US/Pacific'],
        ['-07:00 Arizona', 'US/Arizona'],
        ['-07:00 Chihuahua, La Paz, Mazatlan', 'America/Chihuahua'],
        ['-07:00 Mountain Time (US & Canada)', 'US/Mountain'],
        ['-06:00 Central America', 'America/Guatemala'],
        ['-06:00 Central Time (US & Canada)', 'US/Central'],
        ['-06:00 Guadalajara, Mexico City, Monterrey', 'Mexico/General'],
        ['-06:00 Saskatchewan', 'Canada/Saskatchewan'],
        ['-05:00 Bogota, Lima, Quito', 'America/Bogota'],
        ['-05:00 Eastern Time (US & Canada)', 'US/Eastern'],
        ['-05:00 Indiana (East)', 'US/East-Indiana'],
        ['-04:00 Atlantic Time (Canada)', 'Canada/Atlantic'],
        ['-04:00 Caracas, La Paz', 'America/Caracas'],
        ['-04:00 Santiago', 'America/Santiago'],
        ['-03:30 Newfoundland', 'Canada/Newfoundland'],
        ['-03:00 Brasilia', 'America/Sao_Paulo'],
        ['-03:00 Mondevideo', 'America/Montevideo'],
        ['-03:00 Buenos Aires, Georgetown', 'America/Buenos_Aires'],
        ['-03:00 Greenland', 'America/Godthab'],
        ['-02:00 Mid-Atlantic', 'America/Noronha'],
        ['-01:00 Azores', 'Atlantic/Azores'],
        ['-01:00 Cape Verde Is.', 'Atlantic/Cape_Verde'],
        ['+00:00 Casablanca, Monrovia', 'Africa/Casablanca'],
        ['+00:00 GMT: Dublin, Edinburgh, Lisbon, London', 'Europe/London'],
        ['+01:00 Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna', 'Europe/Amsterdam'],
        ['+01:00 Belgrade, Bratislava, Budapest, Ljubljana, Prague', 'Europe/Belgrade'],
        ['+01:00 Brussels, Copenhagen, Madrid, Paris', 'Europe/Brussels'],
        ['+01:00 Sarajevo, Skopje, Warsaw, Zagreb', 'Europe/Sarajevo'],
        ['+01:00 West Central Africa', 'Africa/Algiers'],
        ['+02:00 Athens, Beirut, Istanbul, Minsk', 'Europe/Athens'],
        ['+02:00 Bucharest', 'Europe/Bucharest'],
        ['+02:00 Cairo', 'Africa/Cairo'],
        ['+02:00 Harare, Pretoria', 'Africa/Harare'],
        ['+02:00 Helsinki, Kyiv, Riga, Sofia, Tallinn, Vilnius', 'Europe/Helsinki'],
        ['+02:00 Jerusalem', 'Asia/Jerusalem'],
        ['+03:00 Baghdad', 'Asia/Baghdad'],
        ['+03:00 Kuwait, Riyadh', 'Asia/Kuwait'],
        ['+03:00 Moscow, St. Petersburg, Volograd', 'Europe/Moscow'],
        ['+03:00 Nairobi', 'Africa/Nairobi'],
        ['+03:30 Tehran', 'Asia/Tehran'],
        ['+04:00 Abu Dhabi, Muscat', 'Asia/Muscat'],
        ['+04:00 Baku, Tbilisi, Yerevan', 'Asia/Baku'],
        ['+04:30 Kabul', 'Asia/Kabul'],
        ['+05:00 Ekaterinburg', 'Asia/Yekaterinburg'],
        ['+05:00 Islamabad, Karachi, Tashkent', 'Asia/Karachi'],
        ['+05:30 Chennai, Kolkata, Mumbai, New Delhi', 'Asia/Calcutta'],
        ['+05:45 Kathmandu', 'Asia/Katmandu'],
        ['+06:00 Almaty, Novosibirsk', 'Asia/Almaty'],
        ['+06:00 Astana, Dhaka', 'Asia/Dhaka'],
        ['+06:00 Sri Jayawardenepura', 'Asia/Colombo'],  #MES- This is in Sri Lanka, and Colombo is the capital of Sri Lanka, so I think this is right
        ['+06:30 Rangoon', 'Asia/Rangoon'],
        ['+07:00 Bangkok, Hanoi, Jakarta', 'Asia/Bangkok'],
        ['+07:00 Krasnoyarsk', 'Asia/Krasnoyarsk'],
        ['+08:00 Beijing, Chongqing, Hong Kong, Urumqi', 'Asia/Hong_Kong'],
        ['+08:00 Ulaan Bataar', 'Asia/Ulaanbaatar'],
        ['+08:00 Irkutsk', 'Asia/Irkutsk'],
        ['+08:00 Kuala Lumpur, Singapore', 'Asia/Kuala_Lumpur'],
        ['+08:00 Perth', 'Australia/Perth'],
        ['+08:00 Taipei', 'Asia/Taipei'],
        ['+09:00 Osaka, Sapporo, Tokyo', 'Asia/Tokyo'],
        ['+09:00 Seoul', 'Asia/Seoul'],
        ['+09:00 Yakutsk', 'Asia/Yakutsk'],
        ['+09:30 Adelaide', 'Australia/Adelaide'],
        ['+09:30 Darwin', 'Australia/Darwin'],
        ['+10:00 Brisbane', 'Australia/Brisbane'],
        ['+10:00 Canberra, Melbourne, Sydney', 'Australia/Sydney'],
        ['+10:00 Guam, Port Moresby', 'Pacific/Guam'],
        ['+10:00 Hobart', 'Australia/Hobart'],
        ['+10:00 Vladivostok', 'Asia/Vladivostok'],
        ['+10:30 Lord Howe', 'Australia/Lord_Howe'],
        ['+11:00 Magadan, Soloman Is., New Caledonia', 'Asia/Magadan'],
        ['+12:00 Auckland, Wellington', 'Pacific/Auckland'],
        ['+12:00 Fiji, Kamchatka, Marshall Is.', 'Pacific/Fiji'],
        ["+13:00 Nuku'alofa", 'Pacific/Tongatapu'],    #MES- Nuku'alofa and Tongatapu are both in Tonga, so I think this is the same
      ]
    
      #MES- Override the Rails function for timezones, returning our own
      def time_zone_options_for_select(selected = nil, priority_zones = nil, model = TimeZone)
        #MES- We do NOT do all the fancy stuff that Rails does- we want to show 
        # only a FEW timezones, the most relevant ones.
        return options_for_select(AVAILABLE_ZONES, selected)
      end
    end
  end
end