#!/usr/bin/perl
use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Data::Dumper;
use POSIX 'strftime';
use Digest::SHA 'sha256_hex';
use Note::Base;

$q = sqltable('ring_email')->get(
	'select' => ['id', 'email'],
	'order' => 'id asc',
	'where' => {
		'email_hash' => ['is', undef],
	},
);

foreach my $r (@$q)
{
	my $ck = sha256_hex('r!ng:'. $r->{'email'});
	sqltable('ring_email')->set(
		'update' => {
			'email_hash' => $ck,
		},
		'where' => {
			'id' => $r->{'id'},
		},
	);
}

