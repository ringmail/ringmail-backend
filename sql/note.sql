CREATE TABLE `note_sequence` (
  `id` bigint(20) unsigned NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT INTO `note_sequence` VALUES (0);

delimiter //

CREATE FUNCTION `nextid`() RETURNS bigint(20) DETERMINISTIC
begin
 declare newid bigint;
 update note_sequence set id = last_insert_id( id + 3 );
 select LAST_INSERT_ID() into newid;
 return newid;
end
//

delimiter ;

CREATE TABLE `note_session` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `data` longblob NOT NULL,
  `ipv4_addr` varchar(15) NOT NULL DEFAULT '',
  `secure` tinyint(1) NOT NULL DEFAULT '0',
  `skey` varchar(32) NOT NULL DEFAULT '',
  `ts_created` datetime NOT NULL,
  `ts_expires` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `skey_1` (`skey`),
  KEY `ts_created_1` (`ts_created`),
  KEY `ts_expires_1` (`ts_expires`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

