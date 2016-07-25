DROP EVENT IF EXISTS ring_cart;
CREATE DEFINER=`root`@`localhost` EVENT `ring_cart` ON SCHEDULE EVERY 5 MINUTE STARTS '2016-07-25 00:00:00' ON COMPLETION NOT PRESERVE ENABLE DO DELETE 
	rh 
FROM 
	ring_hashtag AS rh 
	JOIN ring_cart AS rc ON rc.hashtag_id = rh.id AND rc.user_id = rh.user_id 
WHERE 
	rc.transaction_id IS NULL 
	AND 
	rc.ts < NOW() - INTERVAL 2 HOUR;

INSERT INTO sys_version SET id=7;
