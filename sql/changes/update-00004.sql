CREATE TABLE `ring_user_admin` (
	  `id` bigint unsigned NOT NULL auto_increment,
	  `user_id` bigint unsigned NOT NULL,
	  UNIQUE INDEX `user_id_1` (`user_id`),
	  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT INTO sys_version SET id=4;
