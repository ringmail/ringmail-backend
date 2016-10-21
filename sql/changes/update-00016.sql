ALTER TABLE ring_conversation DROP INDEX from_user_id_1,
                              ADD COLUMN conversation_uuid varchar(36) NULL DEFAULT NULL,
                              ADD UNIQUE conversation_uuid_1 (conversation_uuid),
                              ADD UNIQUE from_user_id_1 (from_user_id, to_user_id);

INSERT INTO sys_version SET id=16;
