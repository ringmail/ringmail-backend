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

if (0)
{
	$out = Ring::API->cmd(
		'path' => ['user', 'target', 'add', 'email'],
		'data' => {
			'user_id' => 33,
			'email' => 'mfrager+alias2@gmail.com',
		},
	);
	print Dumper($out);
}

my $uid = 33;
$out = Ring::API->cmd(
	'path' => ['user', 'target', 'list', 'email'],
	'data' => {
		'user_id' => $uid,
	},
);
print Dumper($out);
if ($out->{'ok'})
{
	foreach my $l (@{$out->{'list'}})
	{
		my $tid = $l->{'target_id'};
		my $rt = Ring::API->cmd(
			'path' => ['user', 'target', 'route'],
			'data' => {
				'target_id' => $tid,
				'user_id' => $uid,
			},
		);
		print "Route: $tid ". Dumper($rt);
	}
}

