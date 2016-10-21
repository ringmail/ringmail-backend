ALTER TABLE `ring_hashtag` ADD COLUMN `free` tinyint(1) NOT NULL DEFAULT 0;

INSERT INTO sys_version SET id=24;
