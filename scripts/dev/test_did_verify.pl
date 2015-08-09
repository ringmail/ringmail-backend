#!/usr/bin/perl -I/home/mfrager/note
use strict;
use warnings;

use vars qw();

$Note::Config::File = '/home/mfrager/note/cfg/note.cfg';
require Note::Config;
$main::note_config = $Note::Config::Data;
use Note::Row;
$Note::Row::Database = $Note::Config::Data->storage()->{'sql_ringmail'};

use Note::Log;

use Ring::Route;

my $did = '2133697501';

my $router = new Ring::Route();
my $qname = $router->get_random_server();
$router->send_request('did_verify', {
	'queuehost' => $qname,
	'did_number' => '1'. $did,
	'verify_code' => '5439',
});

1;

