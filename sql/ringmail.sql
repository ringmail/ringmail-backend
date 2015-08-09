CREATE TABLE `ring_call` (
  `id` bigint unsigned NOT NULL,
  `call_length` bigint,
  `caller_id` bigint unsigned NOT NULL,
  `caller_user_id` bigint unsigned NOT NULL,
  `fs_uuid_aleg` varchar(36),
  `target_did_id` bigint unsigned,
  `target_domain_id` bigint unsigned,
  `target_email_id` bigint unsigned,
  `target_user_id` bigint unsigned,
  `target_type` bigint unsigned NOT NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX fs_uuid_aleg_1 (`fs_uuid_aleg`),
  INDEX caller_user_id_1 (`caller_user_id`, `ts`),
  INDEX target_user_id_1 (`target_user_id`, `ts`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_call_route` (
  `id` bigint unsigned NOT NULL,
  `call_id` bigint unsigned NOT NULL,
  `fs_uuid_bleg` varchar(36),
  `result` varchar(32) NOT NULL,
  `route_did_id` bigint unsigned,
  `route_phone_id` bigint unsigned,
  `route_seq` bigint NOT NULL,
  `route_sip_id` bigint unsigned,
  `route_type` varchar(16) NOT NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ts_bridged` datetime,
  `ts_end` datetime,
  INDEX call_id_1 (`call_id`),
  INDEX fs_uuid_bleg_1 (`fs_uuid_bleg`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_caller` (
  `id` bigint unsigned NOT NULL,
  `caller_type` varchar(16) NOT NULL,
  `cid_name` varchar(128) NOT NULL,
  `cid_number` varchar(15) NOT NULL,
  `did_id` bigint unsigned,
  `phone_id` bigint unsigned,
  `sip_id` bigint unsigned,
  INDEX cid_number_1 (`cid_number`),
  INDEX did_id_1 (`did_id`),
  INDEX phone_id_1 (`phone_id`),
  INDEX sip_id_1 (`sip_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_did` (
  `id` bigint unsigned NOT NULL,
  `did_code` varchar(3) NOT NULL DEFAULT 1,
  `did_number` varchar(14) NOT NULL,
  UNIQUE INDEX did_code_1 (`did_code`, `did_number`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_domain` (
  `id` bigint unsigned NOT NULL,
  `domain` varchar(64) NOT NULL,
  `domain_reverse` varchar(64) NOT NULL,
  UNIQUE INDEX domain_1 (`domain`),
  INDEX domain_reverse_2 (`domain_reverse`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_domain_user` (
  `id` bigint unsigned NOT NULL,
  `domain_id` bigint unsigned NOT NULL,
  `username` varchar(64) NOT NULL,
  UNIQUE INDEX domain_id_1 (`domain_id`, `username`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_email` (
  `id` bigint unsigned NOT NULL,
  `domain_id` bigint unsigned NOT NULL,
  `domain_user_id` bigint unsigned NOT NULL,
  `email` varchar(255) NOT NULL,
  INDEX domain_id_1 (`domain_id`),
  UNIQUE INDEX domain_user_id_1 (`domain_user_id`),
  UNIQUE INDEX email_1 (`email`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_phone` (
  `id` bigint unsigned NOT NULL,
  `gruu` varchar(36),
  `login` varchar(255) NOT NULL,
  `password` varchar(32) NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  INDEX gruu_1 (`gruu`),
  UNIQUE INDEX login_1 (`login`),
  INDEX user_id_1 (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_route` (
  `id` bigint unsigned NOT NULL,
  `did_id` bigint unsigned,
  `email_id` bigint unsigned,
  `phone_id` bigint unsigned,
  `route_type` varchar(16) NOT NULL,
  `sip_id` bigint unsigned,
  `user_id` bigint unsigned NOT NULL,
  UNIQUE INDEX user_id_1 (`user_id`, `sip_id`, `did_id`, `phone_id`, `email_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_sip` (
  `id` bigint unsigned NOT NULL,
  `sip_url` varchar(255) NOT NULL,
  UNIQUE INDEX sip_url_1 (`sip_url`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_target` (
  `id` bigint unsigned NOT NULL,
  `did_id` bigint unsigned,
  `domain_id` bigint unsigned,
  `email_id` bigint unsigned,
  `target_type` varchar(16) NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  UNIQUE INDEX did_id_1 (`did_id`),
  UNIQUE INDEX domain_id_1 (`domain_id`),
  UNIQUE INDEX email_id_1 (`email_id`),
  INDEX user_id_1 (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_target_route` (
  `id` bigint unsigned NOT NULL,
  `route_id` bigint unsigned NOT NULL,
  `seq` bigint NOT NULL,
  `target_id` bigint unsigned NOT NULL,
  INDEX route_id_1 (`route_id`),
  UNIQUE INDEX target_id_1 (`target_id`, `seq`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_user` (
  `id` bigint(20) unsigned NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `login` varchar(255) NOT NULL,
  `password_fs` varchar(32) DEFAULT NULL,
  `password_hash` varchar(128) DEFAULT NULL,
  `password_salt` varchar(128) DEFAULT NULL,
  `person` bigint(20) unsigned DEFAULT NULL,
  `verified` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `login_1` (`login`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_user_did` (
  `id` bigint unsigned NOT NULL,
  `did_id` bigint unsigned NOT NULL,
  `did_label` varchar(64) NOT NULL,
  `did_type` varchar(16) NOT NULL,
  `ts_added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `user_id` bigint unsigned NOT NULL,
  `verified` bool NOT NULL DEFAULT 0,
  UNIQUE INDEX user_id_1 (`user_id`, `did_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_user_domain` (
  `id` bigint unsigned NOT NULL,
  `domain_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  UNIQUE INDEX user_id_1 (`user_id`, `domain_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_user_email` (
  `id` bigint unsigned NOT NULL,
  `email_id` bigint unsigned NOT NULL,
  `primary_email` bool NOT NULL DEFAULT 0,
  `user_id` bigint unsigned NOT NULL,
  UNIQUE INDEX user_id_1 (`user_id`, `email_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_user_service` (
  `id` bigint unsigned NOT NULL,
  `service_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  UNIQUE INDEX user_id_1 (`user_id`, `service_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_user_sip` (
  `id` bigint unsigned NOT NULL,
  `sip_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_verify_did` (
  `id` bigint unsigned NOT NULL,
  `did_id` bigint unsigned NOT NULL,
  `ts_added` datetime NOT NULL,
  `ts_verified` datetime,
  `user_id` bigint unsigned NOT NULL,
  `verified` bool NOT NULL DEFAULT 0,
  `verify_code` varchar(6) NOT NULL,
  UNIQUE INDEX did_id_1 (`did_id`),
  INDEX user_id_1 (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_verify_domain` (
  `id` bigint unsigned NOT NULL,
  `domain_id` bigint unsigned NOT NULL,
  `ts_added` datetime NOT NULL,
  `ts_verified` datetime,
  `user_id` bigint unsigned NOT NULL,
  `verified` bool NOT NULL DEFAULT 0,
  `verify_code` varchar(32) NOT NULL,
  UNIQUE INDEX domain_id_1 (`domain_id`),
  INDEX user_id_1 (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_verify_email` (
  `id` bigint unsigned NOT NULL,
  `email_id` bigint unsigned NOT NULL,
  `ts_added` datetime NOT NULL,
  `ts_verified` datetime,
  `user_id` bigint unsigned NOT NULL,
  `verified` bool NOT NULL DEFAULT 0,
  `verify_code` varchar(32) NOT NULL,
  UNIQUE INDEX email_id_1 (`email_id`),
  INDEX user_id_1 (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_person` (
  `id` bigint unsigned NOT NULL,
  `country` varchar(2),
  `first_name` varchar(255),
  `last_name` varchar(255),
  `us_state` varchar(2),
  `us_zipcode` varchar(5),
  `us_zipcode4` varchar(4),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `payment_card` (
  `id` bigint unsigned NOT NULL,
  `address` varchar(255),
  `address2` varchar(255),
  `cc_expm` varchar(2) NOT NULL,
  `cc_expy` varchar(4) NOT NULL,
  `cc_post` varchar(6) NOT NULL,
  `cc_type` varchar(32) NOT NULL,
  `city` varchar(255),
  `data` blob,
  `data_enc` blob,
  `deleted` bool NOT NULL DEFAULT 0,
  `first_name` varchar(255),
  `last_name` varchar(255),
  `user_id` bigint unsigned NOT NULL,
  `state` varchar(2),
  `use_contact` bool NOT NULL DEFAULT 0,
  `zip` varchar(5),
  INDEX user_1 (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `account` (
  `id` bigint unsigned NOT NULL,
  `balance` decimal(24,4) NOT NULL,
  `last_tx` bigint unsigned,
  `user_id` bigint unsigned NOT NULL,
  `ts_created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ts_updated` datetime,
  INDEX user_1 (`user_id`),
  INDEX ts_created_1 (`ts_created`),
  INDEX ts_updated_1 (`ts_updated`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `account_log` (
  `id` bigint unsigned NOT NULL,
  `account` bigint unsigned NOT NULL,
  `balance` decimal(24,4) NOT NULL,
  `last_tx` bigint unsigned,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX account_1 (`account`),
  INDEX last_tx_1 (`last_tx`),
  INDEX ts_1 (`ts`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `account_name` (
  `id` bigint unsigned NOT NULL,
  `account` bigint unsigned,
  `name` varchar(255) NOT NULL,
  UNIQUE INDEX name_1 (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `payment_attempt` (
  `id` bigint unsigned NOT NULL,
  `accepted` bool NOT NULL DEFAULT 0,
  `account` bigint unsigned NOT NULL,
  `amount` decimal(24,4) NOT NULL,
  `card_id` bigint unsigned NOT NULL,
  `error` bigint unsigned,
  `payment` bigint unsigned,
  `proc_id` bigint unsigned NOT NULL,
  `result` varchar(16) NOT NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `user_id` bigint unsigned NOT NULL,
  INDEX account_1 (`account`),
  INDEX payment_1 (`payment`),
  INDEX ts_1 (`ts`),
  INDEX user_1 (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `payment_proc` (
  `id` bigint unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  UNIQUE INDEX name_1 (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `payment_lock` (
  `id` bigint unsigned NOT NULL,
  `account` bigint unsigned NOT NULL,
  `attempt` bigint unsigned,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE INDEX account_1 (`account`),
  INDEX attempt_1 (`attempt`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `payment_error` (
  `id` bigint unsigned NOT NULL,
  `error_data` blob NOT NULL,
  `error_summary` varchar(16) NOT NULL,
  `error_text` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `payment` (
  `id` bigint unsigned NOT NULL,
  `accepted` bool NOT NULL DEFAULT 0,
  `account` bigint unsigned NOT NULL,
  `amount` decimal(24,4) NOT NULL,
  `card_id` bigint unsigned,
  `proc_id` bigint unsigned NOT NULL,
  `ref_id` varchar(255) NOT NULL,
  `ref_id_2` varchar(255) NOT NULL,
  `reversed` datetime,
  `ts` datetime NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  INDEX account_1 (`account`),
  INDEX card_id_1 (`card_id`),
  INDEX ref_id_1 (`ref_id`(12)),
  INDEX ref_id_2 (`ref_id_2`(12)),
  INDEX reversed_1 (`reversed`),
  INDEX ts_1 (`ts`),
  INDEX user_1 (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `account_transaction` (
  `id` bigint unsigned NOT NULL,
  `acct_dst` bigint unsigned NOT NULL,
  `acct_src` bigint unsigned NOT NULL,
  `amount` decimal(24,4) NOT NULL,
  `entity` bigint unsigned,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tx_type` bigint unsigned NOT NULL,
  `user_id` bigint unsigned,
  INDEX acct_dst_1 (`acct_dst`),
  INDEX acct_src_1 (`acct_src`),
  INDEX entity_1 (`entity`),
  INDEX ts_1 (`ts`),
  INDEX tx_type_1 (`tx_type`),
  INDEX user_1 (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `account_transaction_type` (
  `id` bigint unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  UNIQUE INDEX name_1 (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

delimiter //

create trigger account_tx after update on account for each row begin
  insert into account_log (id, account, last_tx, balance) values (nextid(), old.id, old.last_tx, old.balance);
end
//

create trigger account after insert on account_transaction for each row begin
  update account set balance=balance - new.amount, ts_updated=new.ts, last_tx=new.id where id=new.acct_src;
  update account set balance=balance + new.amount, ts_updated=new.ts, last_tx=new.id where id=new.acct_dst;
end
//

delimiter ;

CREATE TABLE `ring_monthly` (
  `id` bigint unsigned NOT NULL,
  `card_id` bigint unsigned NOT NULL,
  `rebill_date` date NOT NULL,
  `rebill_freq` varchar(16) NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  INDEX rebill_date_1 (`rebill_date`),
  INDEX user_id_1 (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_monthly_product` (
  `id` bigint unsigned NOT NULL,
  `monthly_price` decimal(24,4) NOT NULL,
  `product_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  INDEX user_id_1 (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_product` (
  `id` bigint unsigned NOT NULL,
  `name` varchar(64) NOT NULL,
  UNIQUE INDEX name_1 (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


CREATE TABLE `ring_contact` (
  `id` bigint unsigned NOT NULL auto_increment,
  `apple_id` bigint NULL DEFAULT NULL,
  `first_name` varchar(128) NULL DEFAULT NULL,
  `last_name` varchar(128) NULL DEFAULT NULL,
  `organization` varchar(128) NULL DEFAULT NULL,
  `ts_created` datetime NOT NULL,
  `ts_updated` datetime NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  INDEX `user_id_1` (`user_id`, `apple_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_contact_phone` (
  `id` bigint unsigned NOT NULL auto_increment,
  `contact_id` bigint unsigned NOT NULL,
  `did_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  UNIQUE INDEX `user_id_1` (`user_id`, `contact_id`, `did_id`),
  INDEX `user_id_2` (`user_id`, `did_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_contact_email` (
  `id` bigint unsigned NOT NULL auto_increment,
  `contact_id` bigint unsigned NOT NULL,
  `email_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  UNIQUE INDEX `user_id_1` (`user_id`, `contact_id`, `email_id`),
  INDEX `user_id_2` (`user_id`, `email_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

