CREATE TABLE `comments` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `owner_id` int(11) default NULL,
  `body` varchar(4096) default NULL,
  `created_at` datetime default NULL,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `comments_places` (
  `comment_id` int(11) NOT NULL default '0',
  `place_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`comment_id`,`place_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `comments_plans` (
  `comment_id` int(11) NOT NULL default '0',
  `plan_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`comment_id`,`plan_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `email_ids` (
  `plan_id` int(11) NOT NULL,
  `email_id` varchar(255) NOT NULL,
  PRIMARY KEY  (`plan_id`,`email_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `emails` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `user_id` int(11) NOT NULL,
  `address` varchar(60) NOT NULL default '',
  `confirmed` tinyint(4) default '0',
  `primary` tinyint(4) default '0',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `feedbacks` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `url` varchar(1024) default NULL,
  `user_id` int(11) default NULL,
  `feedback_type` int(11) default NULL,
  `body` varchar(1024) default NULL,
  `stage` int(11) default NULL,
  `owner` varchar(255) default NULL,
  `created_at` datetime default NULL,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `geocode_cache_entries` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `location` varchar(512) default NULL,
  `normalized_location` varchar(512) default NULL,
  `address` varchar(512) default NULL,
  `city` varchar(512) default NULL,
  `state` varchar(512) default NULL,
  `zip` varchar(10) default NULL,
  `lat` float default NULL,
  `long` float default NULL,
  `created_at` datetime default NULL,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`),
  KEY `location_string_index` (`location`(100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `pictures` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `extension` varchar(255) default NULL,
  `content_type` varchar(255) default NULL,
  `data` text,
  `created_at` datetime default NULL,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `place_popularity_stats` (
  `stat_date` date NOT NULL,
  `rank` int(11) NOT NULL,
  `count` int(11) NOT NULL,
  `place_id` int(11) NOT NULL,
  PRIMARY KEY  (`stat_date`,`rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `place_usage_stats` (
  `place_id` int(11) NOT NULL,
  `day` int(11) NOT NULL,
  `hour` int(11) NOT NULL,
  `num_plans` int(11) NOT NULL default '0',
  `num_user_plans` int(11) NOT NULL default '0',
  PRIMARY KEY  (`place_id`,`day`,`hour`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `places` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `user_id` int(11) default NULL,
  `public` tinyint(4) default NULL,
  `location` varchar(512) default NULL,
  `address` varchar(512) default NULL,
  `city` varchar(512) default NULL,
  `state` varchar(512) default NULL,
  `zip` varchar(10) default NULL,
  `lat` float default NULL,
  `long` float default NULL,
  `geocoded` int(11) default '0',
  `url` varchar(512) default NULL,
  `phone` varchar(30) default NULL,
  `normalized_name` varchar(255) default NULL,
  `meta_info` varchar(255) default NULL,
  `created_at` datetime default NULL,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`),
  FULLTEXT KEY `normalized_name` (`normalized_name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE `plan_changes` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `plan_id` int(11) NOT NULL default '0',
  `change_type` int(11) NOT NULL default '0',
  `owner_id` int(11) default NULL,
  `initial_value` varchar(512) default NULL,
  `final_value` varchar(512) default NULL,
  `comment` varchar(4096) default NULL,
  `created_at` datetime default NULL,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `planners` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `user_id` int(11) default NULL,
  `visibility_type` int(11) default NULL,
  `created_at` datetime default NULL,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `planners_plans` (
  `planner_id` int(11) NOT NULL default '0',
  `plan_id` int(11) NOT NULL default '0',
  `cal_pln_status` int(11) default NULL,
  `ownership` int(11) default '0',
  `reminder_state` int(11) default NULL,
  `planner_visibility_cache` int(11) default NULL,
  `place_id_cache` int(11) default NULL,
  `user_id_cache` int(11) default NULL,
  PRIMARY KEY  (`planner_id`,`plan_id`),
  KEY `pp_place_vis_plan_idx` (`place_id_cache`,`planner_visibility_cache`,`cal_pln_status`,`plan_id`),
  KEY `pp_plan_planner_idx` (`plan_id`,`planner_id`),
  KEY `pp_usr_place_plnr_idx` (`user_id_cache`,`place_id_cache`,`cal_pln_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `plans` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `place_id` int(11) default NULL,
  `start` datetime default NULL,
  `duration` int(11) default NULL,
  `fuzzy_start` datetime default NULL,
  `local_start` datetime default NULL,
  `salt` varchar(40) NOT NULL default '',
  `created_at` datetime default NULL,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `sessions` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `sessid` varchar(255) default NULL,
  `data` text,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`),
  KEY `session_index` (`sessid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `user_atts` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `user_id` int(11) NOT NULL,
  `att_id` int(11) NOT NULL,
  `att_value` varchar(255) NOT NULL default '',
  `group_id` int(11) default NULL,
  `created_at` datetime default NULL,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `user_autocomplete` (
  `id` int(11) NOT NULL default '0',
  `user_identifier` varchar(80) NOT NULL default '',
  `prefix1` varchar(1) default NULL,
  `prefix2` varchar(2) default NULL,
  `prefix3` varchar(3) default NULL,
  `prefix4` varchar(4) default NULL,
  `prefix5` varchar(5) default NULL,
  `prefix6` varchar(6) default NULL,
  `prefix7` varchar(7) default NULL,
  `prefix8` varchar(8) default NULL,
  `prefix9` varchar(9) default NULL,
  `prefix10` varchar(10) default NULL,
  KEY `idx_user_auto_prefix1` (`prefix1`),
  KEY `idx_user_auto_prefix2` (`prefix2`),
  KEY `idx_user_auto_prefix3` (`prefix3`),
  KEY `idx_user_auto_prefix4` (`prefix4`),
  KEY `idx_user_auto_prefix5` (`prefix5`),
  KEY `idx_user_auto_prefix6` (`prefix6`),
  KEY `idx_user_auto_prefix7` (`prefix7`),
  KEY `idx_user_auto_prefix8` (`prefix8`),
  KEY `idx_user_auto_prefix9` (`prefix9`),
  KEY `idx_user_auto_prefix10` (`prefix10`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `user_contacts` (
  `user_id` int(11) NOT NULL default '0',
  `contact_id` int(11) NOT NULL default '0',
  `connections` int(11) default '0',
  `friend_status` int(11) default '0',
  `clipboard_status` int(11) default '0',
  `style` varchar(255) default NULL,
  `contact_created_at` datetime default NULL,
  PRIMARY KEY  (`user_id`,`contact_id`),
  KEY `uc_ctc_idx` (`contact_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `users` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `login` varchar(80) NOT NULL default '',
  `salted_password` varchar(40) NOT NULL default '',
  `first_name` varchar(80) default NULL,
  `last_name` varchar(80) default NULL,
  `description` text,
  `salt` varchar(40) NOT NULL default '',
  `role` varchar(40) default NULL,
  `security_token` varchar(40) default NULL,
  `token_expiry` datetime default NULL,
  `deleted` int(11) default '0',
  `delete_after` datetime default NULL,
  `image_id` int(11) default NULL,
  `thumbnail_id` int(11) default NULL,
  `time_zone` varchar(40) default NULL,
  `user_type` int(11) default '0',
  `clipboard_styles` varchar(100) default NULL,
  `created_at` datetime default NULL,
  `updated_at` datetime default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

