#!/usr/bin/perl
use strict;
use warnings;
no warnings qw(uninitialized);

use MIME::Base64;
use JSON::XS;
use Net::RabbitMQ;
use Data::Dumper;
use Digest::MD5 'md5_hex';
use IO::All;
use URI::Encode 'uri_encode', 'uri_decode';
use LWP::UserAgent;

#my $host = $ARGV[0]. '.voip.ringmail.com';
my $host = $ARGV[0]. '.voip.revalead.com';
my $event = 'chat_cmd';
my $data = {
	'to' => $ARGV[1],
	'command' => 'http://www.youtube.com/watch?v=9bZkp7q19f0',
};

my $rbcfg = {
	'host' => 'localhost',
	'user' => 'guest',
	'password' => 'guest',
	'port' => 5673,
};
my $rq = new Net::RabbitMQ();
$rq->connect($rbcfg->{'host'}, {'user' => $rbcfg->{'user'}, 'password' => $rbcfg->{'password'}, 'port' => $rbcfg->{'port'}});
$rq->channel_open(1);
my $json = encode_json([$event, $data]);
$rq->publish(1, 'rgm_'. $host, $json, {'exchange' => 'ringmail'});

1;

