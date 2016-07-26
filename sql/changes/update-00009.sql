ALTER TABLE ring_device DROP INDEX device_uuid_1,
                        DROP INDEX user_id_1,
                        ADD UNIQUE user_id_1 (user_id, device_uuid);

INSERT INTO sys_version SET id=9;
