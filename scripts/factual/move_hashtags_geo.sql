INSERT INTO ring_hashtag (hashtag, category_id, user_id, active, paid, directory)
SELECT d.hashtag, NULL, 291, 1, 1, 1
FROM business_hashtag d WHERE d.hashtag != 'DYL'

---

INSERT INTO ring_hashtag_geo (hashtag_id, category_id, country_code, latitude, longitude, business_place_id)
SELECT h.id, c.internal_category_id, 'us', g.latitude, g.longitude, g.place_id
FROM business_place_category_geo g, business_hashtag t, business_category c, ring_hashtag h
WHERE g.business_hashtag_id=t.id AND t.hashtag=h.hashtag AND g.category_id=c.id AND t.hashtag != 'DYL'

---

UPDATE ring_category c, business_category b SET c.image_card=b.img_url, c.image_header=b.header_img_url WHERE c.id=b.internal_category_id;

