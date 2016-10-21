ALTER TABLE `ring_user_did` CHANGE COLUMN `did_label` `did_label` varchar(64) NOT NULL DEFAULT '';
ALTER TABLE `ring_user_did` CHANGE COLUMN `did_type` `did_type` varchar(16) NOT NULL DEFAULT '';

INSERT INTO sys_version SET id=25;
