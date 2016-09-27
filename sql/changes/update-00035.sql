UPDATE ring_hashtag SET category_id = NULL; 

SET FOREIGN_KEY_CHECKS = 0; 

TRUNCATE ring_category; 

SET FOREIGN_KEY_CHECKS = 1; 

INSERT INTO `ring_category` (`id`, `category`, `category_id`, `ts`, `color_hex`) VALUES 
	(1,'Start ups',NULL,'2016-09-27 00:37:49',NULL),
	(2,'Local Stores',NULL,'2016-09-27 00:37:49',NULL),
	(3,'Home Services',NULL,'2016-09-27 00:37:49',NULL),
	(4,'Insurance',NULL,'2016-09-27 00:37:49',NULL),
	(5,'Finance',NULL,'2016-09-27 00:37:49',NULL),
	(6,'Florist',NULL,'2016-09-27 00:37:49',NULL),
	(7,'Bike shops',NULL,'2016-09-27 00:37:49',NULL),
	(8,'Auto shops',NULL,'2016-09-27 00:37:49',NULL),
	(9,'Dentist',NULL,'2016-09-27 00:37:49',NULL),
	(10,'Hair Salons',NULL,'2016-09-27 00:37:49',NULL),
	(11,'Surf shops',NULL,'2016-09-27 00:37:49',NULL),
	(12,'Bakeries',NULL,'2016-09-27 00:37:49',NULL),
	(13,'Bed & Breakfast',NULL,'2016-09-27 00:37:49',NULL),
	(14,'Dry Cleaners',NULL,'2016-09-27 00:37:49',NULL),
	(15,'Car Rental',NULL,'2016-09-27 00:37:49',NULL),
	(16,'Small Pharmacies',NULL,'2016-09-27 00:37:49',NULL),
	(17,'Bars and night clubs',NULL,'2016-09-27 00:37:49',NULL),
	(18,'Consultant',NULL,'2016-09-27 00:37:49',NULL),
	(19,'Care for the Elderly',NULL,'2016-09-27 00:37:49',NULL),
	(20,'Personal',NULL,'2016-09-27 00:37:49',NULL);

INSERT INTO sys_version SET id=35;
