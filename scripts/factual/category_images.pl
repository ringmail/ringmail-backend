#!/usr/bin/perl -I/home/note/lib -I/home/note/app/ringmail/lib
use strict;
use warnings;

use Data::Dumper;
use Config::General;
use JSON::XS;
use POSIX 'strftime';
use IO::All;

use Note::Base;
use Note::Iterator;

no warnings qw(uninitialized once);

my $iter = new Note::Iterator(
	'file' => 'category_images.csv',
	'type' => 'csv',
	'csv_fields' => 1,
);

while ($iter->has_next())
{
	my $v = $iter->value();
	if (defined($v->{'header_img_url'}) && length($v->{'header_img_url'}))
	{
		my $cid = $v->{'factual_category_id'};
		sqltable('business_category')->set(
			'update' => {
				'header_img_url' => $v->{'header_img_url'},
				'img_url' => $v->{'img_url'},
			},
			'where' => {
				'factual_category_id' => $v->{'factual_category_id'},
			},
		);
	}
}

