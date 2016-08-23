ALTER TABLE `ring_cart` DROP INDEX `coupon_1`,
                        ADD UNIQUE `coupon_id_1` (`coupon_id`);

INSERT INTO sys_version SET id=18;
