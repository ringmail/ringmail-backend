#!/usr/bin/perl -I/home/note/lib -I/home/note/app/ringmail/lib
use strict;
use warnings;

use Data::Dumper;
use Config::General;
use JSON::XS;
use POSIX 'strftime';
use IO::All;

use Note::Base;

no warnings qw(uninitialized once);

my $iter;
$iter = sub {
	my $par = shift;
	my $npar = shift;
	my $q = sqltable('business_category')->get(
		'select' => ['business_category_name', 'id'],
		'where' => {
			'parent' => $par,
		},
		'order' => 'business_category_name asc',
		'array' => 1,
	);
	foreach my $r (@$q)
	{
		my $n = $r->[0];
		my $rc = Note::Row::insert('ring_category' => {
			'category' => $n,
			'category_id' => $npar,
			'color_hex' => '',
			'ts' => strftime("%F %T", localtime()),
		});
		sqltable('business_category')->set(
			'update' => {'internal_category_id' => $rc->id()},
			'where' => {'id' => $r->[1]},
		);
		$iter->($r->[1], $rc->id());
	}
};
$iter->(undef, undef);

