ALTER TABLE `ring_hashtag` ADD COLUMN `directory` tinyint(1) NOT NULL DEFAULT 0;

CREATE TABLE `ring_hashtag_directory` (
  `id` bigint unsigned NOT NULL auto_increment,
  `hashtag_id` bigint unsigned NOT NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ts_created` datetime NOT NULL,
  `ts_directory` datetime NULL DEFAULT NULL,
  `user_id` bigint unsigned NULL,
  UNIQUE INDEX `hashtag_id_1` (`hashtag_id`),
  INDEX (`user_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `ring_user-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
  CONSTRAINT `ring_hashtag-hashtag_id` FOREIGN KEY (`hashtag_id`) REFERENCES `ring_hashtag` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT INTO sys_version SET id=20;
