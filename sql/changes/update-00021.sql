DELIMITER // 

CREATE DEFINER=`root`@`localhost` TRIGGER `ringmail`.`ring_hashtag_directory` AFTER DELETE ON `ringmail`.`ring_hashtag_directory` FOR EACH ROW 
begin
	update 
	ring_hashtag 
	set 
	directory = 0 
	where 
	id = old.hashtag_id;
end

// 

DELIMITER ; 

INSERT INTO sys_version SET id=21;
