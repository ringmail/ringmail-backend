ALTER TABLE ring_device DROP INDEX device_uuid_1,
INDEX user_id_1,
UNIQUE user_id_1 (user_id, device_uuid);

INSERT INTO sys_version SET id=9;
