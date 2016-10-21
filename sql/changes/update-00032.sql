ALTER TABLE `ring_conversation` ADD UNIQUE `from_identity_id_1` (`from_identity_id`, `to_identity_id`);

INSERT INTO sys_version SET id=32;
