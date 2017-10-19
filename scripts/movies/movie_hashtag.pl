#!/usr/bin/perl
use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Data::Dumper;
use Note::Base;
use JSON::XS;

sub add_hashtag
{
	my $tag = shift;
	unless (sqltable('ring_hashtag')->count('hashtag' => $tag))
	{
		Note::Row::insert('ring_hashtag', {
			'hashtag' => $tag,
			'target_url' => '/internal/ringpage/movie?hashtag='. $tag,
			'active' => 1,
			'paid' => 1,
			'directory' => 1,
			'localized' => 0,
		});
	}
}

my $q = sqltable('movie')->get(
	'select' => 'hashtag',
	'order' => 'hashtag asc',
);
foreach my $r (@$q)
{
	add_hashtag($r->{'hashtag'});
}

