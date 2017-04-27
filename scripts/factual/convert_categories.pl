#!/usr/bin/perl
use strict;
use warnings;

use lib '/home/note/lib';
use lib '/home/note/app/ringmail/lib';

use Note::Base;
use Ring::BusinessCategory;
use Note::Iterator;

my $bc = new Ring::BusinessCategory();
my $itr = new Note::Iterator(
	'file' => 'allCats.csv',
	'type' => 'csv',
);

my $csv = Text::CSV_XS->new ({ binary => 1, eol => $/ });
open my $fh, ">", "factual_categories_to_paths.csv" or die "foo.csv: $!";

while ($itr->has_next())
{
	my $val = $itr->value();
	my $catid = $val->[1];
	$val->[1] = join('|', @{$bc->get_path('category_id' => $catid)});
    $csv->print ($fh, $val) or $csv->error_diag;
	::log($val);
}

close $fh;

