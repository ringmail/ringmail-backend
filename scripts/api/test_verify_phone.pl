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

my $urec = new Note::Row(
	'ring_user' => {
		'login' => 'mfrager+f27@gmail.com',
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

my $code = '1319';

my $out;
$out = Ring::API->cmd(
	'path' => ['user', 'target', 'verify', 'did', 'check'],
	'data' => {
		'user_id' => $urec->id(),
		'did_id' => $drec->id(),
		'verify_code' => $code,
	},
);
print Dumper($out);

