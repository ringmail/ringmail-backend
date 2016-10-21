ALTER TABLE `account` ADD CONSTRAINT `account-last_tx` FOREIGN KEY (`last_tx`) REFERENCES `account_transaction` (`id`),
                      ADD CONSTRAINT `account-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `account_log` ADD CONSTRAINT `account_log-account_id` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`),
                          ADD CONSTRAINT `account_log-tx_prev` FOREIGN KEY (`tx_prev`) REFERENCES `account_transaction` (`id`),
                          ADD CONSTRAINT `account_log-tx_new` FOREIGN KEY (`tx_new`) REFERENCES `account_transaction` (`id`);

ALTER TABLE `account_name` ADD CONSTRAINT `account_name-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                           ADD CONSTRAINT `account_name-account_id` FOREIGN KEY (`account`) REFERENCES `account` (`id`);

ALTER TABLE `account_transaction` ADD CONSTRAINT `account_transaction-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                                  ADD CONSTRAINT `account_transaction-tx_type` FOREIGN KEY (`tx_type`) REFERENCES `account_transaction_type` (`id`),
                                  ADD CONSTRAINT `account_transaction-entity` FOREIGN KEY (`entity`) REFERENCES `payment` (`id`),
                                  ADD CONSTRAINT `account_transaction-acct_src` FOREIGN KEY (`acct_src`) REFERENCES `account` (`id`),
                                  ADD CONSTRAINT `account_transaction-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                                  ADD CONSTRAINT `account_transaction-acct_dst` FOREIGN KEY (`acct_dst`) REFERENCES `account` (`id`);

ALTER TABLE `account_transaction_type` ADD CONSTRAINT `account_transaction_type-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `payment` ADD CONSTRAINT `payment-account_id` FOREIGN KEY (`account`) REFERENCES `account` (`id`),
                      ADD CONSTRAINT `payment-proc_id` FOREIGN KEY (`proc_id`) REFERENCES `payment_proc` (`id`),
                      ADD CONSTRAINT `payment-card_id` FOREIGN KEY (`card_id`) REFERENCES `payment_card` (`id`),
                      ADD CONSTRAINT `payment-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                      ADD CONSTRAINT `payment-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `payment_attempt` ADD CONSTRAINT `payment_attempt-proc_id` FOREIGN KEY (`proc_id`) REFERENCES `payment_proc` (`id`),
                              ADD CONSTRAINT `payment_attempt-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                              ADD CONSTRAINT `payment_attempt-card_id` FOREIGN KEY (`card_id`) REFERENCES `payment_card` (`id`),
                              ADD CONSTRAINT `payment_attempt-account_id` FOREIGN KEY (`account`) REFERENCES `account` (`id`),
                              ADD CONSTRAINT `payment_attempt-error_id` FOREIGN KEY (`error`) REFERENCES `payment_error` (`id`),
                              ADD CONSTRAINT `payment_attempt-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                              ADD CONSTRAINT `payment_attempt-payment_id` FOREIGN KEY (`payment`) REFERENCES `payment` (`id`);

ALTER TABLE `payment_card` ADD CONSTRAINT `payment_card-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                           ADD CONSTRAINT `payment_card-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `payment_error` ADD CONSTRAINT `payment_error-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `payment_lock` ADD CONSTRAINT `payment_lock-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                           ADD CONSTRAINT `payment_lock-account_id` FOREIGN KEY (`account`) REFERENCES `account` (`id`);

ALTER TABLE `payment_proc` ADD CONSTRAINT `payment_proc-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_button` ADD CONSTRAINT `ring_button-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                          ADD CONSTRAINT `ring_button-ringpage_id` FOREIGN KEY (`ringpage_id`) REFERENCES `ring_page` (`id`) ON DELETE CASCADE;

ALTER TABLE `ring_cart` ADD CONSTRAINT `ring_cart-order_id` FOREIGN KEY (`order_id`) REFERENCES `ring_order` (`id`),
                        ADD CONSTRAINT `ring_cart-hashtag_id` FOREIGN KEY (`hashtag_id`) REFERENCES `ring_hashtag` (`id`) ON DELETE CASCADE,
                        ADD CONSTRAINT `ring_cart-transaction_id` FOREIGN KEY (`transaction_id`) REFERENCES `account_transaction` (`id`),
                        ADD CONSTRAINT `ring_cart-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                        ADD CONSTRAINT `ring_cart-coupon` FOREIGN KEY (`coupon_id`) REFERENCES `ring_coupon` (`id`);

ALTER TABLE `ring_category` ADD CONSTRAINT `ring_category-category_id` FOREIGN KEY (`category_id`) REFERENCES `ring_category` (`id`);

ALTER TABLE `ring_coupon` ADD CONSTRAINT `coupon-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                          ADD CONSTRAINT `coupon-transaction_id` FOREIGN KEY (`transaction_id`) REFERENCES `account_transaction` (`id`);

ALTER TABLE `ring_did` ADD CONSTRAINT `ring_did-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_domain` ADD CONSTRAINT `ring_domain-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_domain_user` ADD CONSTRAINT `ring_domain_user-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                               ADD CONSTRAINT `ring_domain_user-domain_id` FOREIGN KEY (`domain_id`) REFERENCES `ring_domain` (`id`);

ALTER TABLE `ring_email` ADD CONSTRAINT `ring_email-domain_id` FOREIGN KEY (`domain_id`) REFERENCES `ring_domain` (`id`),
                         ADD CONSTRAINT `ring_email-domain_user_id` FOREIGN KEY (`domain_user_id`) REFERENCES `ring_domain_user` (`id`),
                         ADD CONSTRAINT `ring_email-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_hashtag` ADD CONSTRAINT `ring_hashtag-ringpage_id` FOREIGN KEY (`ringpage_id`) REFERENCES `ring_page` (`id`),
                           ADD CONSTRAINT `ring_hashtag-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                           ADD CONSTRAINT `ring_hashtag-category_id` FOREIGN KEY (`category_id`) REFERENCES `ring_category` (`id`);

ALTER TABLE `ring_order` ADD CONSTRAINT `ring_order-transaction_id` FOREIGN KEY (`transaction_id`) REFERENCES `account_transaction` (`id`),
                         ADD CONSTRAINT `ring_order-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `ring_page` ADD CONSTRAINT `ringpage-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `ring_phone` ADD CONSTRAINT `ring_phone-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                         ADD CONSTRAINT `ring_phone-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `ring_target` ADD CONSTRAINT `ring_target-domain_id` FOREIGN KEY (`domain_id`) REFERENCES `ring_domain` (`id`),
                          ADD CONSTRAINT `ring_target-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                          ADD CONSTRAINT `ring_target-did_id` FOREIGN KEY (`did_id`) REFERENCES `ring_did` (`id`),
                          ADD CONSTRAINT `ring_target-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                          ADD CONSTRAINT `ring_target-email_id` FOREIGN KEY (`email_id`) REFERENCES `ring_email` (`id`);

ALTER TABLE `ring_user` ADD CONSTRAINT `ring_user-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_user_admin` ADD CONSTRAINT `ring_user_admin-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `ring_user_domain` ADD CONSTRAINT `ring_user_domain-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                               ADD CONSTRAINT `ring_user_domain-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                               ADD CONSTRAINT `ring_user_domain-domain_id` FOREIGN KEY (`domain_id`) REFERENCES `ring_domain` (`id`);

ALTER TABLE `ring_user_email` ADD CONSTRAINT `ring_user_email-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                              ADD CONSTRAINT `ring_user_email-email_id` FOREIGN KEY (`email_id`) REFERENCES `ring_email` (`id`),
                              ADD CONSTRAINT `ring_user_email-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `ring_verify_domain` ADD CONSTRAINT `ring_verify_domain-domain_id` FOREIGN KEY (`domain_id`) REFERENCES `ring_domain` (`id`),
                                 ADD CONSTRAINT `ring_verify_domain-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                                 ADD CONSTRAINT `ring_verify_domain-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_verify_email` ADD CONSTRAINT `ring_verify_email-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                                ADD CONSTRAINT `ring_verify_email-email_id` FOREIGN KEY (`email_id`) REFERENCES `ring_email` (`id`),
                                ADD CONSTRAINT `ring_verify_email-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

INSERT INTO sys_version SET id=17;
