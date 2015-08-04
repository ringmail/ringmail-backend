#!/usr/bin/perl -I/home/mfrager/note
use strict;
use warnings;
no warnings qw(once);

use Data::Dumper;
use Carp::Always;

$Note::Config::File = '/home/mfrager/note/cfg/note.cfg';
require Note::Config;
$main::note_config = $Note::Config::Data;
use Note::Row;
$Note::Row::Database = $Note::Config::Data->storage()->{'sql_ringmail'};

use Ring::API;
use Ring::User;

my $urec = new Note::Row(
	'ring_user' => {
		'login' => 'mfrager+f31@gmail.com',
	},
);

die("Bad user") unless ($urec->id());

my $drec = new Note::Row(
	'ring_did' => {
		'did_code' => 1,
		'did_number' => '2133697501',
	},
);

die("Bad phone") unless ($drec->id());

my $uid = $urec->id();
my $user = new Ring::User($uid);
my $tid = $user->get_target_id(
	'did_id' => $drec->id(),
);
my $sel = Ring::API->cmd(
	'path' => ['user', 'endpoint', 'select'],
	'data' => {
		'user_id' => $user->id(),
		'target_id' => $tid,
		'endpoint_type' => 'app',
	},
);

print Dumper($sel);

