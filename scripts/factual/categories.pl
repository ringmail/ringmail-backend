#!/usr/bin/perl -I/home/mfrager/note
use strict;
use warnings;

use Data::Dumper;
use Config::General;
use JSON::XS;
use POSIX 'strftime';
use IO::All;

no warnings qw(uninitialized once);

$Note::Config::File = '/home/mfrager/note/cfg/note.cfg';
require Note::Config;
$main::note_config = $Note::Config::Data;
use Note::Row;
$Note::Row::Database = $Note::Config::Data->storage()->{'sql_ringmail'};

use Note::Factual;

my $ft = new Note::Factual();

my @cat = ();
my $done = 0;
my $offset = 0;
while (! $done)
{
	my $r = $ft->query(
		'url' => "http://api.v3.factual.com/t/place-categories?select=category_id,parents,en&limit=50&offset=$offset",
	);
	my $d = decode_json($r);
	if ($d->{'response'}->{'included_rows'} != 50)
	{
		$done = 1;
	}
	else
	{
		$offset += 50;
	}
	if (ref($d->{'response'}->{'data'}))
	{
		push @cat, @{$d->{'response'}->{'data'}};
	}
}

Dumper(\@cat) > io('factual_categories.pl');

