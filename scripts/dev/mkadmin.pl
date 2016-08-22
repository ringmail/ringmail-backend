#!/usr/bin/perl -I/home/mfrager/note
use autodie;
use lib '/home/note/app/ringmail/lib';
use lib '/home/note/lib';
use Note::Base;
use strict;
use warnings;

no warnings qw(uninitialized);

my $rc = new Note::Row(
	'ring_user' => {
		'id' => $ARGV[0],
	},
);

if ($rc->id())
{
	Note::Row::create('ring_user_admin', {
		'user_id' => $ARGV[0],
	});
}
else
{
	die("Invalid user id: ". $ARGV[0]);
}

