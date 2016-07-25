CREATE DEFINER=`root`@`localhost` EVENT `ring_cart` ON SCHEDULE EVERY 5 MINUTE STARTS '2016-07-25 00:00:00' ON COMPLETION NOT PRESERVE ENABLE DO DELETE FROM 
	ring_cart 
WHERE 
	transaction_id IS NULL 
	AND 
	ts < NOW() - INTERVAL 2 HOUR;

INSERT INTO sys_version SET id=6;
