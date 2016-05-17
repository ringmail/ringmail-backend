#!/usr/bin/perl
use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Data::Dumper;
use POSIX 'strftime';
use Digest::SHA 'sha256_hex';
use Note::Base;

$q = sqltable('ring_did')->get(
	'select' => ['id', 'did_code', 'did_number'],
	'order' => 'id asc',
	'where' => {
		'did_hash' => ['is', undef],
	},
);

foreach my $r (@$q)
{
	my $ck = sha256_hex('r!ng:+'. $r->{'did_code'}. $r->{'did_number'});
	sqltable('ring_did')->set(
		'update' => {
			'did_hash' => $ck,
		},
		'where' => {
			'id' => $r->{'id'},
		},
	);
}

