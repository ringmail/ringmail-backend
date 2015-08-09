#!/usr/bin/perl

use XMLRPC::Lite;
use Data::Dumper;
use Carp;
 
my $r = XMLRPC::Lite
  ->readable(1)
  ->proxy('https://app.ringmail.com/service/xmlrpc')
#  ->proxy('http://staging.dyl.com/cgi/printenv')
#  ->check_account('mfrager+test1@gmail.com');
#  ->create_account_with_useragent('mfrager+test4@gmail.com', 'test', 'Test UA');
#  ->check_account_validated('mfrager+test1@gmail.com');
  ->check_sync('test');

#print Dumper([$r->result, $r->status, $r->message]);
#print Dumper($r);

if ($r->fault) { die $r->faultstring }

print $r->result(). "\n";
