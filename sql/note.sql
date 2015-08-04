CREATE TABLE `note_sequence` (
  `id` bigint(20) unsigned NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT INTO `note_sequence` VALUES (0);

delimiter //

CREATE DEFINER=`root`@`localhost` FUNCTION `nextid`() RETURNS bigint(20) DETERMINISTIC
begin
 declare newid bigint;
 update note_sequence set id = last_insert_id( id + 3 );
 select LAST_INSERT_ID() into newid;
 return newid;
end
//

delimiter ;

CREATE TABLE `note_session` (
  `id` bigint unsigned NOT NULL,
  `ipv4_addr` bigint NOT NULL,
  `secure` bool NOT NULL DEFAULT 0,
  `skey` varchar(32) NOT NULL,
  `ts_created` datetime NOT NULL,
  `ts_expires` datetime NOT NULL,
  UNIQUE INDEX skey_1 (`skey`),
  INDEX ts_expires_1 (`ts_expires`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `note_session_data` (
  `id` bigint unsigned NOT NULL,
  `data` longblob NOT NULL,
  `dkey` varchar(64) NOT NULL,
  `session_id` bigint unsigned NOT NULL,
  UNIQUE INDEX session_id_1 (`session_id`, `dkey`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

