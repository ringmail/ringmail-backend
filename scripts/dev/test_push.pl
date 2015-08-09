#!/usr/bin/perl

use Net::APNS::Feedback;
use Data::Dumper;

my $fb = Net::APNS::Feedback->new({
   #'sandbox' => 1,
   'cert' => '/home/mfrager/ringmail_apns_prod.pem',
   'key' => '/home/mfrager/ringmail_apns_prod_key.pem',
});
my @feedback = $fb->retrieve_feedback;
print Dumper(\@feedback);

