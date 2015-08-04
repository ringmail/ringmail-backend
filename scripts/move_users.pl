#!/usr/bin/perl -I/home/mfrager/note
use strict;
use warnings;
no warnings qw(uninitialized);

use Data::Dumper;

$Note::Config::File = '/home/mfrager/note/cfg/note.cfg';
require Note::Config;
$main::note_config = $Note::Config::Data;
use Note::Row;
$Note::Row::Database = $Note::Config::Data->storage()->{'sql_ringmail'};

my $openser = $Note::Config::Data->storage()->{'rgm_openser'};

use Note::SQL::Table 'sqltable';

my $q = sqltable('ring_user')->get(
	'select' => ['login', 'password_fs'],
	#'order' => 'id asc limit 10',
);

my $x = 0;
foreach my $r (@$q)
{
	$r->{'login'} =~ s/\@/%40/;
	if ($openser->table('subscriber')->count(
		'username' => $r->{'login'},
	)) {
		$openser->table('subscriber')->set(
			'update' => {
				'ha1' => $r->{'password_fs'},
			},
			'update' => {
				'username' => $r->{'login'},
			},
		);
	}
	else
	{
		$openser->table('subscriber')->set(
			'insert' => {
				'username' => $r->{'login'},
				'domain' => 'sip.ringmail.com',
				'ha1' => $r->{'password_fs'},
			},
		);
	}
	$x++;
	print "$x\n";
}

#print Dumper($q);

