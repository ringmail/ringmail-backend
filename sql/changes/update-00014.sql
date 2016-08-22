CREATE TABLE `ring_coupon` (
  `id` bigint unsigned NOT NULL auto_increment,
  `amount` decimal(24,2) NOT NULL DEFAULT '0',
  `code` varchar(8) NOT NULL DEFAULT '',
  `transaction_id` bigint unsigned NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `user_id` bigint unsigned NULL,
  UNIQUE INDEX `code_1` (`code`),
  INDEX `transaction_id_1` (`transaction_id`),
  INDEX `user_id_1` (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT INTO sys_version SET id=14;
