ALTER TABLE `account` ADD INDEX `last_tx_1` (`last_tx`),
                      ADD INDEX `user_1` (`user_id`),
                      ADD INDEX (`id`),
                      ADD CONSTRAINT `account-last_tx` FOREIGN KEY (`last_tx`) REFERENCES `account_transaction` (`id`),
                      ADD CONSTRAINT `account-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `account_log` ADD INDEX `account_id_1` (`account_id`),
                          ADD INDEX `tx_new_1` (`tx_new`),
                          ADD INDEX `tx_prev_1` (`tx_prev`),
                          ADD INDEX (`id`),
                          ADD CONSTRAINT `account_log-account_id` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`),
                          ADD CONSTRAINT `account_log-tx_prev` FOREIGN KEY (`tx_prev`) REFERENCES `account_transaction` (`id`),
                          ADD CONSTRAINT `account_log-tx_new` FOREIGN KEY (`tx_new`) REFERENCES `account_transaction` (`id`),
                          ADD CONSTRAINT `account_log-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `account_name` ADD INDEX `account_id_1` (`account`),
                           ADD INDEX (`id`),
                           ADD UNIQUE `name_1` (`name`),
                           ADD CONSTRAINT `account_name-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                           ADD CONSTRAINT `account_name-account_id` FOREIGN KEY (`account`) REFERENCES `account` (`id`);

ALTER TABLE `account_transaction` ADD INDEX `acct_dst_1` (`acct_dst`),
                                  ADD INDEX `acct_src_1` (`acct_src`),
                                  ADD INDEX `entity_1` (`entity`),
                                  ADD INDEX `ts_1` (`ts`),
                                  ADD INDEX `tx_type_1` (`tx_type`),
                                  ADD INDEX `user_1` (`user_id`),
                                  ADD INDEX (`id`),
                                  ADD CONSTRAINT `account_transaction-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                                  ADD CONSTRAINT `account_transaction-tx_type` FOREIGN KEY (`tx_type`) REFERENCES `account_transaction_type` (`id`),
                                  ADD CONSTRAINT `account_transaction-entity` FOREIGN KEY (`entity`) REFERENCES `payment` (`id`),
                                  ADD CONSTRAINT `account_transaction-acct_src` FOREIGN KEY (`acct_src`) REFERENCES `account` (`id`),
                                  ADD CONSTRAINT `account_transaction-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                                  ADD CONSTRAINT `account_transaction-acct_dst` FOREIGN KEY (`acct_dst`) REFERENCES `account` (`id`);

ALTER TABLE `account_transaction_type` ADD INDEX (`id`),
                                       ADD UNIQUE `name_1` (`name`),
                                       ADD CONSTRAINT `account_transaction_type-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `note_session` ADD INDEX `ts_created_1` (`ts_created`),
                           ADD INDEX `ts_expires_1` (`ts_expires`),
                           ADD UNIQUE `skey_1` (`skey`);

ALTER TABLE `payment` ADD INDEX `account_1` (`account`),
                      ADD INDEX `card_id_1` (`card_id`),
                      ADD INDEX `proc_id_1` (`proc_id`),
                      ADD INDEX `ref_id_1` (`ref_id`),
                      ADD INDEX `reversed_1` (`reversed`),
                      ADD INDEX `ts_1` (`ts`),
                      ADD INDEX `user_1` (`user_id`),
                      ADD INDEX (`id`),
                      ADD CONSTRAINT `payment-account_id` FOREIGN KEY (`account`) REFERENCES `account` (`id`),
                      ADD CONSTRAINT `payment-proc_id` FOREIGN KEY (`proc_id`) REFERENCES `payment_proc` (`id`),
                      ADD CONSTRAINT `payment-card_id` FOREIGN KEY (`card_id`) REFERENCES `payment_card` (`id`),
                      ADD CONSTRAINT `payment-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                      ADD CONSTRAINT `payment-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `payment_attempt` ADD INDEX `account_1` (`account`),
                              ADD INDEX `card_id_1` (`card_id`),
                              ADD INDEX `error_id_1` (`error`),
                              ADD INDEX `payment_id` (`payment`),
                              ADD INDEX `proc_id_1` (`proc_id`),
                              ADD INDEX `user_1` (`user_id`),
                              ADD INDEX (`id`),
                              ADD CONSTRAINT `payment_attempt-proc_id` FOREIGN KEY (`proc_id`) REFERENCES `payment_proc` (`id`),
                              ADD CONSTRAINT `payment_attempt-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                              ADD CONSTRAINT `payment_attempt-card_id` FOREIGN KEY (`card_id`) REFERENCES `payment_card` (`id`),
                              ADD CONSTRAINT `payment_attempt-account_id` FOREIGN KEY (`account`) REFERENCES `account` (`id`),
                              ADD CONSTRAINT `payment_attempt-error_id` FOREIGN KEY (`error`) REFERENCES `payment_error` (`id`),
                              ADD CONSTRAINT `payment_attempt-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                              ADD CONSTRAINT `payment_attempt-payment_id` FOREIGN KEY (`payment`) REFERENCES `payment` (`id`);

ALTER TABLE `payment_card` ADD INDEX `user_1` (`user_id`),
                           ADD INDEX (`id`),
                           ADD CONSTRAINT `payment_card-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                           ADD CONSTRAINT `payment_card-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `payment_error` ADD INDEX (`id`),
                            ADD CONSTRAINT `payment_error-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `payment_lock` ADD INDEX (`id`),
                           ADD UNIQUE `account_id` (`account`),
                           ADD CONSTRAINT `payment_lock-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                           ADD CONSTRAINT `payment_lock-account_id` FOREIGN KEY (`account`) REFERENCES `account` (`id`);

ALTER TABLE `payment_proc` ADD INDEX (`id`),
                           ADD UNIQUE `name` (`name`),
                           ADD CONSTRAINT `payment_proc-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_button` ADD INDEX `ringpage_id_1` (`ringpage_id`),
                          ADD INDEX `user_id_1` (`user_id`),
                          ADD INDEX (`id`),
                          ADD CONSTRAINT `ring_button-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                          ADD CONSTRAINT `ring_button-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                          ADD CONSTRAINT `ring_button-ringpage_id` FOREIGN KEY (`ringpage_id`) REFERENCES `ring_page` (`id`) ON DELETE CASCADE;

ALTER TABLE `ring_call` ADD INDEX `caller_user_id_1` (`caller_user_id`, `ts`),
                        ADD INDEX `fs_uuid_aleg_1` (`fs_uuid_aleg`),
                        ADD INDEX `target_user_id_1` (`target_user_id`, `ts`);

ALTER TABLE `ring_call_route` ADD INDEX `call_id_1` (`call_id`),
                              ADD INDEX `fs_uuid_bleg_1` (`fs_uuid_bleg`);

ALTER TABLE `ring_caller` ADD INDEX `cid_number_1` (`cid_number`),
                          ADD INDEX `did_id_1` (`did_id`),
                          ADD INDEX `phone_id_1` (`phone_id`),
                          ADD INDEX `sip_id_1` (`sip_id`);

ALTER TABLE `ring_cart` ADD INDEX `order_id_1` (`order_id`),
                        ADD INDEX `user_id_1` (`user_id`),
                        ADD INDEX (`id`),
                        ADD UNIQUE `coupon_1` (`coupon_id`),
                        ADD UNIQUE `hashtag_id_1` (`hashtag_id`),
                        ADD UNIQUE `transaction_id_1` (`transaction_id`),
                        ADD CONSTRAINT `ring_cart-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                        ADD CONSTRAINT `ring_cart-order_id` FOREIGN KEY (`order_id`) REFERENCES `ring_order` (`id`),
                        ADD CONSTRAINT `ring_cart-hashtag_id` FOREIGN KEY (`hashtag_id`) REFERENCES `ring_hashtag` (`id`) ON DELETE CASCADE,
                        ADD CONSTRAINT `ring_cart-transaction_id` FOREIGN KEY (`transaction_id`) REFERENCES `account_transaction` (`id`),
                        ADD CONSTRAINT `ring_cart-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                        ADD CONSTRAINT `ring_cart-coupon` FOREIGN KEY (`coupon_id`) REFERENCES `ring_coupon` (`id`);

ALTER TABLE `ring_category` ADD INDEX `category_id_1` (`category_id`),
                            ADD INDEX (`id`),
                            ADD UNIQUE `category` (`category`),
                            ADD CONSTRAINT `ring_category-category_id` FOREIGN KEY (`category_id`) REFERENCES `ring_category` (`id`),
                            ADD CONSTRAINT `ring_category-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_contact` ADD INDEX `user_id_1` (`user_id`),
                           ADD INDEX `user_id_2` (`user_id`, `matched_user_id`),
                           ADD UNIQUE `device_id_1` (`device_id`, `internal_id`);

ALTER TABLE `ring_contact_email` ADD INDEX `email_hash_1` (`email_hash`),
                                 ADD UNIQUE `contact_id_1` (`contact_id`, `email_hash`);

ALTER TABLE `ring_contact_phone` ADD INDEX `phone_hash_1` (`phone_hash`),
                                 ADD UNIQUE `contact_id_1` (`contact_id`, `phone_hash`);

ALTER TABLE `ring_conversation` ADD UNIQUE `conversation_code_1` (`conversation_code`),
                                ADD UNIQUE `from_user_id_1` (`from_user_id`, `to_user_id`, `to_user_target_id`);

ALTER TABLE `ring_coupon` ADD INDEX `transaction_id_1` (`transaction_id`),
                          ADD INDEX `user_id_1` (`user_id`),
                          ADD INDEX (`id`),
                          ADD UNIQUE `code_1` (`code`),
                          ADD CONSTRAINT `coupon-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                          ADD CONSTRAINT `coupon-transaction_id` FOREIGN KEY (`transaction_id`) REFERENCES `account_transaction` (`id`),
                          ADD CONSTRAINT `coupon-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_device` ADD INDEX `user_id_1` (`user_id`),
                          ADD UNIQUE `device_uuid_1` (`device_uuid`);

ALTER TABLE `ring_did` ADD INDEX `did_hash_1` (`did_hash`),
                       ADD INDEX (`id`),
                       ADD UNIQUE `did_code_1` (`did_code`, `did_number`),
                       ADD CONSTRAINT `ring_did-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_domain` ADD INDEX `domain_reverse_2` (`domain_reverse`),
                          ADD INDEX (`id`),
                          ADD UNIQUE `domain_1` (`domain`),
                          ADD CONSTRAINT `ring_domain-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_domain_user` ADD INDEX (`id`),
                               ADD UNIQUE `domain_id_1` (`domain_id`, `username`),
                               ADD CONSTRAINT `ring_domain_user-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                               ADD CONSTRAINT `ring_domain_user-domain_id` FOREIGN KEY (`domain_id`) REFERENCES `ring_domain` (`id`);

ALTER TABLE `ring_email` ADD INDEX `domain_id_1` (`domain_id`),
                         ADD INDEX `email_hash_1` (`email_hash`),
                         ADD INDEX (`id`),
                         ADD UNIQUE `domain_user_id_1` (`domain_user_id`),
                         ADD UNIQUE `email_1` (`email`),
                         ADD CONSTRAINT `ring_email-domain_id` FOREIGN KEY (`domain_id`) REFERENCES `ring_domain` (`id`),
                         ADD CONSTRAINT `ring_email-domain_user_id` FOREIGN KEY (`domain_user_id`) REFERENCES `ring_domain_user` (`id`),
                         ADD CONSTRAINT `ring_email-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_hashtag` ADD INDEX `category_id_1` (`category_id`),
                           ADD INDEX `ringpage_id_1` (`ringpage_id`),
                           ADD INDEX `ts_expires_1` (`ts_expires`),
                           ADD INDEX `user_id_1` (`user_id`),
                           ADD INDEX (`id`),
                           ADD UNIQUE `hashtag_1` (`hashtag`),
                           ADD CONSTRAINT `ring_hashtag-ringpage_id` FOREIGN KEY (`ringpage_id`) REFERENCES `ring_page` (`id`),
                           ADD CONSTRAINT `ring_hashtag-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                           ADD CONSTRAINT `ring_hashtag-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                           ADD CONSTRAINT `ring_hashtag-category_id` FOREIGN KEY (`category_id`) REFERENCES `ring_category` (`id`);

ALTER TABLE `ring_monthly` ADD INDEX `rebill_date_1` (`rebill_date`),
                           ADD INDEX `user_id_1` (`user_id`);

ALTER TABLE `ring_monthly_product` ADD INDEX `user_id_1` (`user_id`);

ALTER TABLE `ring_order` ADD INDEX `user_id_1` (`user_id`),
                         ADD INDEX (`id`),
                         ADD UNIQUE `transaction_id_1` (`transaction_id`),
                         ADD CONSTRAINT `ring_order-transaction_id` FOREIGN KEY (`transaction_id`) REFERENCES `account_transaction` (`id`),
                         ADD CONSTRAINT `ring_order-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                         ADD CONSTRAINT `ring_order-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `ring_page` ADD INDEX `user_id_1` (`user_id`),
                        ADD INDEX (`id`),
                        ADD CONSTRAINT `ringpage-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                        ADD CONSTRAINT `ringpage-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `ring_phone` ADD INDEX `gruu_1` (`gruu`),
                         ADD INDEX `user_id_1` (`user_id`),
                         ADD INDEX (`id`),
                         ADD UNIQUE `login_1` (`login`),
                         ADD CONSTRAINT `ring_phone-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                         ADD CONSTRAINT `ring_phone-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `ring_product` ADD UNIQUE `name_1` (`name`);

ALTER TABLE `ring_route` ADD UNIQUE `user_id_1` (`user_id`, `sip_id`, `did_id`, `phone_id`, `email_id`);

ALTER TABLE `ring_sip` ADD UNIQUE `sip_url_1` (`sip_url`);

ALTER TABLE `ring_target` ADD INDEX `user_id_1` (`user_id`),
                          ADD INDEX (`id`),
                          ADD UNIQUE `did_id_1` (`did_id`),
                          ADD UNIQUE `domain_id_1` (`domain_id`),
                          ADD UNIQUE `email_id_1` (`email_id`),
                          ADD CONSTRAINT `ring_target-domain_id` FOREIGN KEY (`domain_id`) REFERENCES `ring_domain` (`id`),
                          ADD CONSTRAINT `ring_target-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                          ADD CONSTRAINT `ring_target-did_id` FOREIGN KEY (`did_id`) REFERENCES `ring_did` (`id`),
                          ADD CONSTRAINT `ring_target-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                          ADD CONSTRAINT `ring_target-email_id` FOREIGN KEY (`email_id`) REFERENCES `ring_email` (`id`);

ALTER TABLE `ring_target_route` ADD INDEX `route_id_1` (`route_id`),
                                ADD UNIQUE `target_id_1` (`target_id`, `seq`);

ALTER TABLE `ring_user` ADD INDEX (`id`),
                        ADD UNIQUE `aws_user_id_1` (`aws_user_id`),
                        ADD UNIQUE `login_1` (`login`),
                        ADD CONSTRAINT `ring_user-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_user_admin` ADD INDEX (`id`),
                              ADD UNIQUE `user_id_1` (`user_id`),
                              ADD CONSTRAINT `ring_user_admin-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                              ADD CONSTRAINT `ring_user_admin-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_user_apns` ADD UNIQUE `user_id_1` (`user_id`);

ALTER TABLE `ring_user_contact_sync` ADD UNIQUE `user_id_1` (`user_id`, `device_id`);

ALTER TABLE `ring_user_did` ADD INDEX `did_id_1` (`did_id`),
                            ADD UNIQUE `user_id_1` (`user_id`, `did_id`);

ALTER TABLE `ring_user_domain` ADD INDEX `domain_id_1` (`domain_id`),
                               ADD INDEX (`id`),
                               ADD UNIQUE `user_id_1` (`user_id`, `domain_id`),
                               ADD CONSTRAINT `ring_user_domain-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                               ADD CONSTRAINT `ring_user_domain-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                               ADD CONSTRAINT `ring_user_domain-domain_id` FOREIGN KEY (`domain_id`) REFERENCES `ring_domain` (`id`);

ALTER TABLE `ring_user_email` ADD INDEX `email_id_1` (`email_id`),
                              ADD INDEX (`id`),
                              ADD UNIQUE `user_id_1` (`user_id`, `email_id`),
                              ADD CONSTRAINT `ring_user_email-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                              ADD CONSTRAINT `ring_user_email-email_id` FOREIGN KEY (`email_id`) REFERENCES `ring_email` (`id`),
                              ADD CONSTRAINT `ring_user_email-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

ALTER TABLE `ring_user_pwreset` ADD UNIQUE `reset_hash_1` (`reset_hash`),
                                ADD UNIQUE `user_id_1` (`user_id`);

ALTER TABLE `ring_user_service` ADD UNIQUE `user_id_1` (`user_id`, `service_id`);

ALTER TABLE `ring_verify_did` ADD INDEX `user_id_1` (`user_id`),
                              ADD UNIQUE `did_id_1` (`did_id`);

ALTER TABLE `ring_verify_domain` ADD INDEX `user_id_1` (`user_id`),
                                 ADD INDEX (`id`),
                                 ADD UNIQUE `domain_id_1` (`domain_id`),
                                 ADD CONSTRAINT `ring_verify_domain-domain_id` FOREIGN KEY (`domain_id`) REFERENCES `ring_domain` (`id`),
                                 ADD CONSTRAINT `ring_verify_domain-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`),
                                 ADD CONSTRAINT `ring_verify_domain-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`);

ALTER TABLE `ring_verify_email` ADD INDEX `user_id_1` (`user_id`),
                                ADD INDEX (`id`),
                                ADD UNIQUE `email_id_1` (`email_id`),
                                ADD CONSTRAINT `ring_verify_email-id` FOREIGN KEY (`id`) REFERENCES `note_sequence` (`id`),
                                ADD CONSTRAINT `ring_verify_email-email_id` FOREIGN KEY (`email_id`) REFERENCES `ring_email` (`id`),
                                ADD CONSTRAINT `ring_verify_email-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

INSERT INTO sys_version SET id=17;
