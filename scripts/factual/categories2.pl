#!/usr/bin/perl -I/home/mfrager/note
use strict;
use warnings;

use Data::Dumper;
use Config::General;
use JSON::XS;
use POSIX 'strftime';
use IO::All;

no warnings qw(uninitialized once);

my $data < io('factual_categories.pl');
my $v = eval $data;
foreach my $c (sort {$a->{'en'} cmp $b->{'en'}} @$v)
{
	print "$c->{'en'}\n";
}

