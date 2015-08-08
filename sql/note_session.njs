{
   "columns" : {
      "data" : {
         "default" : "",
         "length" : "long",
         "name" : "data",
         "null" : 0,
         "type" : "binary"
      },
      "ipv4_addr" : {
         "default" : "",
         "length" : "15",
         "name" : "ipv4_addr",
         "null" : 0,
         "type" : "text"
      },
      "secure" : {
         "default" : "0",
         "name" : "secure",
         "null" : 0,
         "type" : "boolean"
      },
      "skey" : {
         "default" : "",
         "length" : "32",
         "name" : "skey",
         "null" : 0,
         "type" : "text"
      },
      "ts_created" : {
         "name" : "ts_created",
         "null" : 0,
         "type" : "datetime"
      },
      "ts_expires" : {
         "name" : "ts_expires",
         "null" : 0,
         "type" : "datetime"
      }
   },
   "index" : {
      "skey_1" : {
         "columns" : [
            "skey"
         ],
         "name" : "skey_1",
         "type" : "unique"
      },
      "ts_created_1" : {
         "columns" : [
            "ts_created"
         ],
         "name" : "ts_created_1",
         "type" : "index"
      },
      "ts_expires_1" : {
         "columns" : [
            "ts_expires"
         ],
         "name" : "ts_expires_1",
         "type" : "index"
      }
   },
   "primary_key" : {
      "mode" : "auto_inc",
      "name" : "id",
      "type" : "record"
   }
}
