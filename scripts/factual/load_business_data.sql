ALTER TABLE business_hashtag_place AUTO_INCREMENT=1;
LOAD DATA INFILE '/var/lib/mysql-files/business_hashtag_place_CA.tab' IGNORE INTO TABLE business_hashtag_place(hashtag,place_id);

ALTER TABLE business_hashtag AUTO_INCREMENT=1;
LOAD DATA INFILE '/var/lib/mysql-files/business_hashtag_CA.tab' IGNORE INTO TABLE business_hashtag(hashtag);

ALTER TABLE business_place_category_geo AUTO_INCREMENT=1;
LOAD DATA INFILE '/var/lib/mysql-files/business_place_category_geo_CA.tab' IGNORE INTO TABLE business_place_category_geo(business_hashtag_id,category_id,latitude,longitude,place_id);

ALTER TABLE business_place_category AUTO_INCREMENT=1;
LOAD DATA INFILE '/var/lib/mysql-files/business_place_category_CA.tab' IGNORE INTO TABLE business_place_category(place_id,category_id);

ALTER TABLE business_place_factual AUTO_INCREMENT=1;
LOAD DATA INFILE '/var/lib/mysql-files/business_place_factual_CA.tab' IGNORE INTO TABLE business_place_factual(factual_category_id,place_id);

ALTER TABLE business_place AUTO_INCREMENT=1;
LOAD DATA INFILE '/var/lib/mysql-files/business_place_CA.tab' IGNORE INTO TABLE business_place(address,address_extended,admin_region,chain_id,chain_name,country,email,existence,factual_id,fax,hours,hours_display,latitude,locality,longitude,name,neighborhood,po_box,post_town,postcode,region,tel,website);

