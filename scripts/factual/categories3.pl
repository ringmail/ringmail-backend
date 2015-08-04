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

my %mp = ();
foreach my $c (sort {$a->{'en'} cmp $b->{'en'}} @$v)
{
	$mp{$c->{'en'}} = $c;
}

sub items
{
	my $parent_id = shift;
	my @res = ();
	foreach my $c (sort {$a->{'en'} cmp $b->{'en'}} @$v)
	{
		if ($c->{'parents'}->[0] == $parent_id)
		{
			push @res, $c->{'en'};
		}
	}
	return @res;
}

my @top = items(1);
my $iter;
$iter = sub {
	my $i = shift;
	my $d = shift;
	foreach my $t (@$d)
	{
		my $row = "\t" x $i;
		$row .= "$t\n";
		print $row;
		my $ct = $mp{$t};
		my @sub = items($ct->{'category_id'});
		if (scalar @sub)
		{
			$iter->($i + 1, \@sub);
		}
	}
};

$iter->(0, \@top);

