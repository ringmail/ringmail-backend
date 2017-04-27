#!/usr/bin/python

import ast
import re

# build dictionary of factual category ids and ringmail category id
dictCats = {}
with open('./allCats.csv','rb') as allCatsIn:
    for line in allCatsIn:
        [factualId,catId] = line.split(",")
        dictCats[str(factualId)] = str(catId.rstrip())
allCatsIn.close()

# output files
business_hashtag_Out = open('./business_hashtag_CA.tab', 'wb')
business_place_Out = open('./business_place_CA.tab','wb')
business_hashtag_place_Out = open('./business_hashtag_place_CA.tab', 'wb')
business_place_factual_Out = open('./business_place_factual_CA.tab', 'wb')
business_place_cat_Out = open('./business_place_category_CA.tab','wb')
business_place_category_geo_Out = open('./business_place_category_geo_CA.tab', 'wb')

# process factual tab data
with open('./us_places.factual.v3_47.1478125682.tab','rb') as tsvIn:
    placeId = 1
    hashtagDict = {}
    for line in tsvIn:
        fields = line.split("\t")

        # Legend
        # factual_id = fields[0]
        # name = fields[1]
        # address = fields[2]
        # address_extended = fields[3]
        # po_box = fields[4]
        # locality = fields[5]
        # region = fields[6]
        # post_town = fields[7]
        # admin_region = fields[8]
        # postcode = fields[9]
        # country = fields[10]
        # tel = fields[11]
        # fax = fields[12]
        # latitude = fields[13]
        # longitude = fields[14]
        # neighborhood = fields[15]
        # website = fields[16]
        # email = fields[17]
        # category_ids = fields[18]
        # category_labels = fields[19]
        # chain_name = fields[20]
        # chain_id = fields[21]
        # hours = fields[22]
        # hours_display = fields[23]
        # existence = fields[24]

        name = str(re.sub(r"\\'", "", fields[1]))
        po_box = str(re.sub(r"[^0-9]", "", fields[4]))
        locality = str(re.sub(r"\\'", "", fields[5]))
        tel = str(re.sub(r"[^0-9]", "", fields[11]))
        fax = str(re.sub(r"[^0-9]", "", fields[12]))
        website = re.sub(r"[^a-zA-Z0-9\\.\\:\\/]", "", fields[16])
        chain_name = str(re.sub(r"\\'", "", fields[20]))
        
        if tel:
            tel = "+1" + tel
        if fax:
            fax = "+1" + fax

        # lat long null correction
        if not fields[13]:
            fields[13] = "0.0";
        if not fields[14]:
            fields[14] = "0.0";


        if fields[6] == "CA":
            hashtag = re.sub(r"&", "And", name)
            hashtag = re.sub(r"[^a-zA-Z0-9\\&]", "", hashtag)
            hashtagDict[hashtag] = 1

            placeIdStr = str(placeId)
            
            business_place_Out.write(str(fields[2]) + '\t' + str(fields[3]) + '\t' + str(fields[8])+ '\t' + str(fields[21])+ '\t' + chain_name + '\t' + str(fields[10]) + '\t' + str(fields[17]) + '\t' + str(fields[24].rstrip()) + '\t' + str(fields[0]) + '\t' + fax + '\t' + str(fields[22]) + '\t' + str(fields[23]) + '\t' + str(fields[13]) + '\t' + locality + '\t' + str(fields[14]) + '\t' + name + '\t' + str(fields[15]) + '\t' + po_box + '\t' + str(fields[7]) + '\t' + str(fields[9]) + '\t' + str(fields[6]) + '\t' + tel + '\t' + website + '\n')
            business_hashtag_place_Out.write(hashtag + '\t' + placeIdStr + '\n')
            
            if fields[18]:
                factIds = ast.literal_eval(fields[18])
                for factId in factIds:
                    business_place_factual_Out.write(str(factId) + '\t' + placeIdStr + '\n')
                    try:
                        ringCatId = dictCats[str(factId)]
                        business_place_cat_Out.write(placeIdStr + '\t' + ringCatId + '\n')
                        business_place_category_geo_Out.write(placeIdStr + '\t' + ringCatId + '\t' + str(fields[13]) + '\t' + str(fields[14]) + '\t' + placeIdStr + '\n')
                    except:
                        ringCatIdNull = 0
            placeId += 1

    # sort and write unique hashtags
    keylist = hashtagDict.keys()
    keylist.sort()
    for key in keylist:
        business_hashtag_Out.write(key + '\n')

# close output files
business_hashtag_Out.close()
business_place_Out.close()
business_hashtag_place_Out.close()
business_place_factual_Out.close()
business_place_cat_Out.close()
business_place_category_geo_Out.close()

# close main input file
tsvIn.close()
