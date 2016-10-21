ALTER TABLE `ring_coupon` ADD COLUMN `sent` tinyint(1) NOT NULL DEFAULT 0;

INSERT INTO sys_version SET id=22;
