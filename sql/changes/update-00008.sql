ALTER TABLE coupon DROP COLUMN amount;
ALTER TABLE coupon ADD UNIQUE code_1 (code);

INSERT INTO sys_version SET id=8;
