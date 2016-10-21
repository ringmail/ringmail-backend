ALTER TABLE `ring_category` ADD COLUMN `color_hex` text NOT NULL;

INSERT INTO sys_version SET id=31;
