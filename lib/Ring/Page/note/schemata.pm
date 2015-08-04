package Page::note::schemata;
use strict;
use warnings;
no warnings 'uninitialized';

use Moose;
use Data::Dumper;
use Note::Schema;

extends 'Note::Page';

has 'schema_root' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => sub { return './schema' },
);

sub load
{
	my ($obj, $param) = $_[0]->param(@_);
	#my $txt = Dumper(\@page::note::schemata::ISA, $param);
	#my $txt = Dumper(\@page::note::schemata::ISA, $_[1], $p);
	return $txt;
}

sub get_schema_list
{
	my ($obj, $param) = $_[0]->param(@_);
	opendir(my $dh, $obj->schema_root());
	my @files = grep { /\.njs$/ } readdir($dh);
	closedir($dh);
	return \@files;
}

sub load_schema
{
	my ($obj, $param) = $_[0]->param(@_);
	my $name = $param->{'name'};
	my $fp = $obj->schema_root(). '/'. $name. '.njs';
	my $so = new Note::Schema(
		'file' => $fp,
	);
	my $data = $so->load_file();
	return $data;
}

1;

