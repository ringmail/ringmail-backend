SET FOREIGN_KEY_CHECKS = 0;

ALTER TABLE `account_transaction` ADD CONSTRAINT `account_transaction-entity` FOREIGN KEY (`entity`) REFERENCES `payment` (`id`);
ALTER TABLE `account_transaction` ADD CONSTRAINT `account_transaction-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `ring_cart` DROP INDEX `ring_cart-coupon`;

ALTER TABLE `ring_conversation` DROP INDEX `from_identity_id_1`;
ALTER TABLE `ring_conversation` DROP COLUMN `from_identity_id`;
ALTER TABLE `ring_conversation` DROP COLUMN `to_identity_id`;
ALTER TABLE `ring_conversation` ADD COLUMN `from_user_id` bigint(20) unsigned NOT NULL;
ALTER TABLE `ring_conversation` ADD COLUMN `to_user_id` bigint(20) unsigned NOT NULL;
ALTER TABLE `ring_conversation` ADD UNIQUE `from_user_id_1` (`from_user_id`, `to_user_id`);

ALTER TABLE `ring_hashtag` ADD CONSTRAINT `ring_hashtag-ringpage_id` FOREIGN KEY (`ringpage_id`) REFERENCES `ring_page` (`id`);

ALTER TABLE `ring_hashtag_directory` DROP INDEX user_id_3;

ALTER TABLE `ring_phone` ADD CONSTRAINT `ring_phone-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `ring_target` DROP INDEX `hashtag_id_1`;
ALTER TABLE `ring_target` DROP COLUMN `hashtag_id`;
ALTER TABLE `ring_target` ADD CONSTRAINT `ring_target-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);
ALTER TABLE `ring_target` ADD CONSTRAINT `ring_target-email_id` FOREIGN KEY (`email_id`) REFERENCES `ring_email` (`id`);

ALTER TABLE `ring_user_email` ADD CONSTRAINT `ring_user_email-email_id` FOREIGN KEY (`email_id`) REFERENCES `ring_email` (`id`);
ALTER TABLE `ring_user_email` ADD CONSTRAINT `ring_user_email-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `ring_verify_email` ADD CONSTRAINT `ring_verify_email-email_id` FOREIGN KEY (`email_id`) REFERENCES `ring_email` (`id`);
ALTER TABLE `ring_verify_email` ADD CONSTRAINT `ring_verify_email-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO sys_version SET id=27;
