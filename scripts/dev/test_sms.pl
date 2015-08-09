#!/usr/bin/perl5.10.1
require ESL;

use Data::Dumper;

ESL::eslSetLogLevel(7);

my $con = new ESL::ESLconnection("127.0.0.1", "8021", "9032dncw8xb2e6dn7");

print (($con->connected()) ? "Connected\n" : "Not Connected\n");

my $e = new ESL::ESLevent("custom", "SMS::SEND_MESSAGE");
$e->addHeader("to", "u_33\@sip.ringmail.com");
$e->addHeader("from", "mike%40dyl.com\@sip.ringmail.com");
$e->addHeader("type", "text/plain");
$e->addHeader("sip_profile", "internal");
$e->addHeader("dest_proto", "sip");
$e->addBody('Hello World! - '. int(rand(1000)));

my $r = $con->sendEvent($e);

print $r->serialize();
