SET FOREIGN_KEY_CHECKS = 0;

ALTER TABLE `ring_page` ADD CONSTRAINT `ringpage-user_id` FOREIGN KEY (`user_id`) REFERENCES `ring_user` (`id`);

SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO sys_version SET id=29;
