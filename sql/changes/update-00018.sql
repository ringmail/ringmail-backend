ALTER TABLE `ring_coupon` DROP FOREIGN KEY `coupon-id`,
                          DROP FOREIGN KEY `coupon-transaction_id`,
                          DROP FOREIGN KEY `coupon-user_id`,
                          ADD CONSTRAINT `ring_coupon-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                          ADD CONSTRAINT `ring_coupon-transaction_id` FOREIGN KEY (`transaction_id`) REFERENCES `account_transaction` (`id`),
                          ADD CONSTRAINT `ring_coupon-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

INSERT INTO sys_version SET id=18;
