CREATE TABLE `ring_conversation_identity` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `domain_id` bigint(20) unsigned DEFAULT NULL,
  `hashtag_id` bigint(20) unsigned DEFAULT NULL,
  `identity_type` varchar(32) NOT NULL DEFAULT '',
  `user_id` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `domain_id_1` (`domain_id`),
  UNIQUE KEY `hashtag_id_1` (`hashtag_id`),
  KEY `user_id_1` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

ALTER TABLE `ring_cart` DROP INDEX hashtag_id_1;
ALTER TABLE `ring_cart` DROP INDEX transaction_id_1;
ALTER TABLE `ring_cart` ADD UNIQUE `hashtag_id_1` (`hashtag_id`);
ALTER TABLE `ring_cart` ADD UNIQUE `transaction_id_1` (`transaction_id`);

SET FOREIGN_KEY_CHECKS = 0;
ALTER TABLE `ring_conversation` DROP COLUMN `from_user_id`;
ALTER TABLE `ring_conversation` DROP COLUMN `to_user_id`;
ALTER TABLE `ring_conversation` ADD COLUMN `from_identity_id` bigint(20) unsigned NOT NULL;
ALTER TABLE `ring_conversation` ADD COLUMN `to_identity_id` bigint(20) unsigned NOT NULL;
ALTER TABLE `ring_conversation` ADD UNIQUE `from_identity_id_1` (`from_identity_id`, `to_identity_id`);
SET FOREIGN_KEY_CHECKS = 1;

ALTER TABLE `ring_target` ADD COLUMN `hashtag_id` bigint(20) unsigned NULL;
ALTER TABLE `ring_target` ADD UNIQUE `hashtag_id_1` (`hashtag_id`);

INSERT INTO sys_version SET id=30;

