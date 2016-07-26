ALTER TABLE coupon DROP COLUMN amount;
ALTER TABLE coupon DROP INDEX transaction_id_1,
                   DROP INDEX user_id_1;
ALTER TABLE coupon ADD UNIQUE code_1 (code);

INSERT INTO sys_version SET id=8;
