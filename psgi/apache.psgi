#!/usr/bin/perl

use lib qw(/home/note/run);

use Data::Dumper;
use JSON::XS;
use DBI;
use DBIx::Connector;
use Plack::Builder;

use Note::PSGI;
use Note::Factual;

my $obj = new Note::PSGI();
my $root = '/home/note/run';
$obj->setup(
	'config_file' => $root. '/cfg/note.cfg',
);

my $app = sub {
	$obj->run_psgi(@_);
};

$app;
