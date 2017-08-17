#!/usr/bin/perl
use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Data::Dumper;
use Note::Base;

my $r = sqltable('ring_user')->get(
	'select' => 'login',
	'order' => 'login asc',
);
foreach my $c (@$r)
{
	print "$c->{'login'}\n";
}

