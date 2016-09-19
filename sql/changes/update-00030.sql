ALTER TABLE `ring_category` ADD COLUMN `color_hex` text NOT NULL;

ALTER TABLE `ring_conversation` DROP INDEX `from_user_id_1`;
ALTER TABLE `ring_conversation` DROP COLUMN `from_user_id`;
ALTER TABLE `ring_conversation` DROP COLUMN `to_user_id`;
ALTER TABLE `ring_conversation` ADD COLUMN `from_identity_id` bigint(20) unsigned NOT NULL;
ALTER TABLE `ring_conversation` ADD COLUMN `to_identity_id` bigint(20) unsigned NOT NULL;
ALTER TABLE `ring_conversation` ADD UNIQUE `from_identity_id_1` (`from_identity_id`, `to_identity_id`);

ALTER TABLE `ring_target` ADD COLUMN `hashtag_id` bigint(20) unsigned NULL;
ALTER TABLE `ring_target` ADD UNIQUE `hashtag_id_1` (`hashtag_id`);

INSERT INTO sys_version SET id=30;
