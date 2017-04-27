import MySQLdb

db = MySQLdb.connect("localhost", "admin", "KHKgq2opGBsuLSP2kKuAwXGSx", "ringmail")
cursor = db.cursor()

def insertQuery(idIn, catIdIn, nameIn, parentIn):
    try:
        query = """INSERT INTO business_category (factual_category_id, business_category_name, parent) VALUES (%s, '%s', %s);""" % (catIdIn, nameIn, parentIn)
        cursor.execute(query)
    except MySQLdb.IntegrityError as e:
        if not e[0] == 1062:
            raise
        else:
            print "ERROR 1062: " + e[1]

# Places
# Shopping
# Community and Government
# Services
# Organizations
# Healthcare
# Entertainment
# Food and Dining
# Sports and Recreation
# Travel

ShopFlag = 0
CommFlag = 0
ServFlag = 0
OrgaFlag = 0
HealFlag = 0
PersFlag = 0
EnteFlag = 0
FoodFlag = 0
SporFlag = 0
TravFlag = 0

count = 1
parent = 1
branchPrev = ""
leafOut = ""
topCount = 0
branchCount = 0

# insertQuery(1, , "Places", "NULL")
# count += 1

with open('./Factual_Cat_Flat_NEW_sorted.tsv','rb') as tsvIn:
    for line in tsvIn:
        [catId, topLevel, branch, leafIn] = line.split("\t")

        if topLevel == "Shopping" and ShopFlag == 0:
            ShopFlag = count
            parent = 1
            leafOut = topLevel
            insertQuery(count, "NULL", leafOut.rstrip(), "NULL")
            parent = count
            count += 1
            topCount = parent
        if topLevel == "Community and Government" and CommFlag == 0:
            CommFlag = count
            parent = 1
            leafOut = topLevel
            insertQuery(count, "NULL", leafOut.rstrip(), "NULL")
            parent = count
            count += 1
            topCount = parent
        if topLevel == "Services" and ServFlag == 0:
            ServFlag = count
            parent = 1
            leafOut = topLevel
            insertQuery(count, "NULL", leafOut.rstrip(), "NULL")
            parent = count
            count += 1
            topCount = parent
        if topLevel == "Organizations" and OrgaFlag == 0:
            OrgaFlag = count
            parent = 1
            leafOut = topLevel
            insertQuery(count, "NULL", leafOut.rstrip(), "NULL")
            parent = count
            count += 1
            topCount = parent
        if topLevel == "Healthcare" and HealFlag == 0:
            HealFlag = count
            parent = 1
            leafOut = topLevel
            insertQuery(count, "NULL", leafOut.rstrip(), "NULL")
            parent = count
            count += 1
            topCount = parent
        if topLevel == "Personal Care" and PersFlag == 0:
            PersFlag = count
            parent = 1
            leafOut = topLevel
            insertQuery(count, "NULL", leafOut.rstrip(), "NULL")
            parent = count
            count += 1
            topCount = parent
        if topLevel == "Entertainment" and EnteFlag == 0:
            EnteFlag = count
            parent = 1
            leafOut = topLevel
            insertQuery(count, "NULL", leafOut.rstrip(), "NULL")
            parent = count
            count += 1
            topCount = parent
        if topLevel == "Food and Dining" and FoodFlag == 0:
            FoodFlag = count
            parent = 1
            leafOut = topLevel
            insertQuery(count, "NULL", leafOut.rstrip(), "NULL")
            parent = count
            count += 1
            topCount = parent
        if topLevel == "Sports and Recreation" and SporFlag == 0:
            SporFlag = count
            parent = 1
            leafOut = topLevel
            insertQuery(count, "NULL", leafOut.rstrip(), "NULL")
            parent = count
            count += 1
            topCount = parent
        if topLevel == "Travel" and TravFlag == 0:
            TravFlag = count
            parent = 1
            leafOut = topLevel
            insertQuery(count, "NULL", leafOut.rstrip(), "NULL")
            parent = count
            count += 1
            topCount = parent

        if branch:
            if branch != branchPrev:
                leafOut = branch
                branchCount = count
                insertQuery(count, "NULL", leafOut.rstrip(), topCount)
                parent = branchCount
                count += 1
            else:
                parent = branchCount
        else:
            parent = topCount

        leafOut = leafIn

        insertQuery(count, catId, leafOut.rstrip(), parent)

        branchPrev = branch

        count += 1

db.commit()
db.close()


