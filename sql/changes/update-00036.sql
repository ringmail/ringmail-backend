ALTER TABLE `ring_conversation` DROP COLUMN `from_user_id`;
ALTER TABLE `ring_conversation` DROP COLUMN `to_user_id`;

INSERT INTO sys_version SET id=36;
