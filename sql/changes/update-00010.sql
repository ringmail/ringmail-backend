ALTER TABLE coupon ADD COLUMN amount decimal(24, 2) NOT NULL DEFAULT 0;

INSERT INTO sys_version SET id=10;
