CREATE TABLE `sys_version` (
  `id` bigint unsigned NOT NULL auto_increment,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

ALTER TABLE account DROP INDEX ts_created_1,
                    DROP INDEX ts_updated_1,
                    ADD INDEX last_tx_1 (last_tx);

ALTER TABLE account_name ADD INDEX account_id_1 (account);

-- Done
--ALTER TABLE note_sequence ADD COLUMN timestamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
--                          CHANGE COLUMN id id bigint(20) unsigned NOT NULL auto_increment,
--                          ADD PRIMARY KEY (id);
--

CREATE TABLE `payment_attempt` (
  `id` bigint unsigned NOT NULL,
  `accepted` tinyint(1) NOT NULL DEFAULT '0',
  `account` bigint unsigned NOT NULL,
  `amount` decimal(24,2) NOT NULL DEFAULT '0',
  `card_id` bigint unsigned NOT NULL,
  `error` bigint unsigned NULL,
  `payment` bigint unsigned NULL,
  `proc_id` bigint unsigned NOT NULL,
  `result` varchar(16) NOT NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `user_id` bigint unsigned NOT NULL,
  INDEX `account_1` (`account`),
  INDEX `card_id_1` (`card_id`),
  INDEX `payment_attempt-error_id` (`error`),
  INDEX `payment_id` (`payment`),
  INDEX `proc_id_1` (`proc_id`),
  INDEX `user_1` (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `payment_lock` (
  `id` bigint unsigned NOT NULL,
  `account` bigint unsigned NOT NULL,
  `attempt` bigint unsigned NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE INDEX `account_id` (`account`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `payment_proc` (
  `id` bigint unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  UNIQUE INDEX `name` (`name`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_button` (
  `id` bigint unsigned NOT NULL auto_increment,
  `button` text NOT NULL,
  `ringpage_id` bigint unsigned NOT NULL,
  `timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `uri` text NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  INDEX `button-user_id` (`user_id`),
  INDEX `ring_button-ringpage_id` (`ringpage_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_category` (
  `id` bigint unsigned NOT NULL auto_increment,
  `category` varchar(255) NOT NULL DEFAULT '',
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE INDEX `category` (`category`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

ALTER TABLE ring_email CHANGE COLUMN domain_id domain_id bigint(20) unsigned NULL,
                       CHANGE COLUMN domain_user_id domain_user_id bigint(20) unsigned NULL;

ALTER TABLE ring_hashtag ADD COLUMN category_id bigint(20) unsigned NULL,
                         ADD COLUMN ringpage_id bigint(20) unsigned NULL,
                         ADD INDEX category_id_1 (category_id),
                         ADD INDEX ringpage_id_1 (ringpage_id);

CREATE TABLE `ring_page` (
  `id` bigint unsigned NOT NULL auto_increment,
  `body_background_color` text NOT NULL,
  `body_background_image` text NOT NULL,
  `body_header` text NOT NULL,
  `body_text` text NOT NULL,
  `body_text_color` text NOT NULL,
  `footer_background_color` text NOT NULL,
  `footer_text` text NOT NULL,
  `footer_text_color` text NOT NULL,
  `header_background_color` text NOT NULL,
  `header_subtitle` text NOT NULL,
  `header_text_color` text NOT NULL,
  `header_title` text NOT NULL,
  `offer` tinyint(1) NOT NULL DEFAULT '0',
  `ringpage` varchar(128) NOT NULL DEFAULT '',
  `template_id` bigint unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `user_id` bigint unsigned NOT NULL,
  `video` tinyint(1) NOT NULL DEFAULT '0',
  INDEX `ringpage-template_id` (`template_id`),
  INDEX `ringpage-user_id` (`user_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `ring_template` (
  `id` bigint unsigned NOT NULL auto_increment,
  `path` varchar(128) NOT NULL DEFAULT '',
  `template` varchar(128) NOT NULL DEFAULT '',
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE INDEX `template` (`template`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT INTO sys_version SET id=1;

