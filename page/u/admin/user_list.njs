{
   "class" : "Page::ring::setup::admin::user_list",
   "command" : {
      "add_user" : "add_user",
      "login" : "login",
      "make_admin" : "make_admin"
   },
   "init" : [
      "valid_user",
      "role_admin"
   ],
   "template" : "u/settings/admin/user_list.html"
}
