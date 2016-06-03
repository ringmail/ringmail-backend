#!/usr/bin/perl
use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Carp::Always;
use Data::Dumper;
use POSIX 'strftime';
use Note::Base;
use Note::Account;

my $q = sqltable('ring_user')->get(
	'select' => 'id',
	'array' => 1,
);

my $created = 0;
foreach my $urec (@$q)
{
	if (! Note::Account::has_account($urec->[0]))
	{
		Note::Account::create_account($urec->[0]);
		$created++;
	}
}

::log("Created: $created");

