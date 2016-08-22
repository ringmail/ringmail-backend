ALTER TABLE ring_hashtag ADD COLUMN active tinyint(1) NOT NULL DEFAULT 1,
ADD COLUMN paid tinyint(1) NOT NULL DEFAULT 0;

INSERT INTO sys_version SET id=1;
