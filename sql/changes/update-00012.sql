ALTER TABLE ring_cart ADD COLUMN coupon_id bigint(20) unsigned NULL,
                      CHANGE COLUMN hashtag_id hashtag_id bigint(20) unsigned NULL;
ALTER TABLE ring_cart DROP INDEX hashtag_id_1,
                      DROP INDEX transaction_id_1,
                      ADD UNIQUE coupon_1 (coupon_id),
                      ADD UNIQUE hashtag_id_1 (hashtag_id),
                      ADD UNIQUE transaction_id_1 (transaction_id);
ALTER TABLE ring_cart ADD COLUMN order_id bigint(20) unsigned NULL;
ALTER TABLE ring_order ADD COLUMN total decimal(24, 2) NULL;

INSERT INTO sys_version SET id=12;
