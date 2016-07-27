CREATE TABLE `coupon` (
	  `id` bigint unsigned NOT NULL auto_increment,
	  `code` varchar(8) NOT NULL DEFAULT '',
	  `transaction_id` bigint unsigned NULL,
	  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
	  `user_id` bigint unsigned NULL,
	  UNIQUE INDEX `code_1` (`code`),
	  INDEX `transaction_id_1` (`transaction_id`),
	  INDEX `user_id_1` (`user_id`),
	  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT INTO sys_version SET id=8;
