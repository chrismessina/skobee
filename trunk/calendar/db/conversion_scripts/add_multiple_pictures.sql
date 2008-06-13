UPDATE
 users
SET
 thumbnail_id = NULL
WHERE
 thumbnail_id IS NOT NULL AND
 NOT EXISTS
 (
    SELECT *
    FROM
      pictures
    WHERE
      pictures.id = users.thumbnail_id
  );

UPDATE
 users
SET
 image_id = NULL
WHERE
 image_id IS NOT NULL AND
 NOT EXISTS
 (
    SELECT *
    FROM
      pictures
    WHERE
      pictures.id = users.image_id
  );

DROP TABLE IF EXISTS `pictures_users`;
CREATE TABLE `pictures_users` (
  `user_id` int(11) NOT NULL,
  `picture_id` int(11) NOT NULL,
  PRIMARY KEY (`user_id`, `picture_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
ALTER TABLE `pictures_users` ADD INDEX (`picture_id`, `user_id`);

ALTER TABLE `pictures` ADD COLUMN `original_id` int(11) AFTER `id`;
ALTER TABLE `pictures` ADD COLUMN `height` int(11) AFTER `content_type`;
ALTER TABLE `pictures` ADD COLUMN `width` int(11) AFTER `height`;
ALTER TABLE `pictures` ADD COLUMN `size_type` int(11) AFTER `width`;

ALTER TABLE `users` ADD COLUMN `medium_image_id` int(11) AFTER `image_id`;

#MES- After creating the columns, they need to be populated
#	Run "ruby script/runner -e production User.update_old_pics_table"