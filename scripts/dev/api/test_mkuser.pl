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

my $out;

$out = Ring::API->cmd(
	'path' => ['user', 'create'],
	'data' => {
		'name' => 'Mike Test',
		'email' => 'mfrager+f27@gmail.com',
		'phone' => '2133697501',
		'password' => 'test',
		'password2' => 'test',
		'send_sms' => 1,
	},
);
print Dumper($out);

