CREATE TABLE `emails` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `user_id` int(11) NOT NULL default '0',
  `address` varchar(60) NOT NULL default '',
  `confirmed` tinyint(4) default '0',
  `primary` tinyint(4) default '0',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO
	emails (emails.user_id, emails.address, emails.confirmed, emails.primary)
	SELECT users.id, users.email, users.verified, 1 FROM users;

ALTER TABLE users DROP COLUMN verified;
ALTER TABLE users DROP COLUMN email;