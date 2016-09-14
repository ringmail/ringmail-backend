#!/usr/bin/perl
use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Data::Dumper;
use POSIX 'strftime';
use Digest::SHA 'sha256_hex';
use URI::Escape 'uri_escape';
use Note::Base;

my $tbl = sqltable('ring_hashtag');
my $q = $tbl->get(
	'array' => 1,
	'select' => ['id', 'user_id'],
	'where' => 'not exists (select t.id from ring_target t where t.hashtag_id = ring_hashtag.id)',
);
::log("Count: ". scalar(@$q));
foreach my $r (@$q)
{
	Note::Row::create('ring_target', {
		'target_type' => 'hashtag',
		'hashtag_id' => $r->[0],
		'user_id' => $r->[1],
	});
}

