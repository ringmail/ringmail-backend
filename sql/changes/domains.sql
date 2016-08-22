ALTER TABLE ring_user_domain ADD COLUMN verified tinyint(1) NOT NULL DEFAULT 0;
ALTER TABLE ring_user_domain ADD COLUMN ts_added timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP;

