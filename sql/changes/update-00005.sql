ALTER TABLE ring_user_admin ADD COLUMN ts_created timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP;

INSERT INTO sys_version SET id=5;
